#!/bin/bash
# .github/scripts/run-with-fallback.sh
# Model rotation wrapper for opencode CLI
#
# This script implements automatic model rotation/fallback mechanism.
# When the primary model fails (non-zero exit code), it automatically
# rotates to fallback models in priority order until one succeeds or
# all models are exhausted.
#
# Environment Variables Required:
#   FALLBACK_MODELS - Comma-separated list of models in priority order
#                     (e.g., "antigravity/claude-opus-4-5,antigravity/claude-sonnet-4")
#
# Usage:
#   echo "prompt" | ./run-with-fallback.sh --share -
#   ./run-with-fallback.sh --share - < prompt.md

set -o pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
CONFIG_PATH="$HOME/.config/opencode/opencode.json"
MAX_RETRY_DELAY=5  # seconds between retries

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo "[MODEL-ROTATION] $1"
}

log_warning() {
    echo "::warning::[MODEL-ROTATION] $1"
}

log_error() {
    echo "::error::[MODEL-ROTATION] $1"
}

log_notice() {
    echo "::notice::[MODEL-ROTATION] $1"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Check if error is non-rotatable (authentication/config issues)
# Returns 0 (true) if we should NOT rotate, 1 (false) if ok to rotate
is_non_rotatable_error() {
    local error_output="$1"
    if echo "$error_output" | grep -qiE "(authentication failed|invalid api key|unauthorized|401|invalid_api_key|api key invalid)"; then
        return 0  # true - don't rotate
    fi
    return 1  # false - ok to rotate
}

# Update opencode.json with a new model
update_config_model() {
    local new_model="$1"
    
    if [ ! -f "$CONFIG_PATH" ]; then
        log_error "Config file not found: $CONFIG_PATH"
        return 1
    fi
    
    # Validate that jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        return 1
    fi
    
    # Update the model field in the config
    local updated_config
    updated_config=$(jq --arg model "$new_model" '.model = $model' "$CONFIG_PATH" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to update config with jq: $updated_config"
        return 1
    fi
    
    # Validate the output is valid JSON before writing
    if ! echo "$updated_config" | jq empty 2>/dev/null; then
        log_error "Generated config is not valid JSON"
        return 1
    fi
    
    echo "$updated_config" > "$CONFIG_PATH"
    log_info "Updated config to use model: $new_model"
    return 0
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

main() {
    local opencode_args=("$@")
    
    # Capture stdin if piped (for prompts)
    # This is critical because we need to replay the prompt for each retry
    local stdin_content=""
    if [ ! -t 0 ]; then
        stdin_content=$(cat)
    fi
    
    # Validate FALLBACK_MODELS is set
    if [ -z "$FALLBACK_MODELS" ]; then
        log_error "FALLBACK_MODELS environment variable is not set"
        log_info "Falling back to direct opencode execution without rotation"
        if [ -n "$stdin_content" ]; then
            echo "$stdin_content" | opencode "${opencode_args[@]}"
        else
            opencode "${opencode_args[@]}"
        fi
        exit $?
    fi
    
    # Parse FALLBACK_MODELS into array (comma-separated)
    IFS=',' read -ra MODELS <<< "$FALLBACK_MODELS"
    local total_models=${#MODELS[@]}
    
    if [ $total_models -eq 0 ]; then
        log_error "No models configured in FALLBACK_MODELS"
        exit 1
    fi
    
    log_info "Starting with $total_models model(s) available for rotation"
    log_info "Model priority order: ${MODELS[*]}"
    
    local attempt=0
    local last_exit_code=1
    local last_error_output=""
    local successful_model=""
    
    for model in "${MODELS[@]}"; do
        # Trim leading/trailing whitespace
        model=$(echo "$model" | xargs)
        [ -z "$model" ] && continue

        attempt=$((attempt + 1))
        log_info "Attempt $attempt/$total_models: Trying model '$model'"
        
        # Update config with current model
        if ! update_config_model "$model"; then
            log_warning "Failed to update configuration for model '$model', trying next..."
            continue
        fi
        
        # Create a temporary file to capture both stdout and stderr
        local temp_output
        temp_output=$(mktemp)
        
        # Execute opencode with captured stdin
        if [ -n "$stdin_content" ]; then
            echo "$stdin_content" | opencode "${opencode_args[@]}" > "$temp_output" 2>&1
            last_exit_code=$?
        else
            opencode "${opencode_args[@]}" > "$temp_output" 2>&1
            last_exit_code=$?
        fi
        
        # Read the output
        last_error_output=$(cat "$temp_output")
        rm -f "$temp_output"
        
        # Check result
        if [ $last_exit_code -eq 0 ]; then
            successful_model="$model"
            log_notice "SUCCESS: Completed with model '$model' (attempt $attempt/$total_models)"
            # Output the actual response to stdout
            echo "$last_error_output"
            exit 0
        fi
        
        # Failure - log and check if we should rotate
        log_warning "Model '$model' failed with exit code $last_exit_code"
        
        # Check for non-rotatable errors (auth issues shared across all models)
        if is_non_rotatable_error "$last_error_output"; then
            log_error "Non-rotatable error detected (authentication/config issue). Stopping rotation."
            log_error "This error affects all models since they share the same API configuration."
            echo "$last_error_output"
            exit $last_exit_code
        fi
        
        # If more models available, wait briefly before retry
        if [ $attempt -lt $total_models ]; then
            log_info "Waiting ${MAX_RETRY_DELAY}s before trying next model..."
            sleep $MAX_RETRY_DELAY
        fi
    done
    
    # All models exhausted
    log_error "FAILURE: All $total_models models exhausted"
    log_error "Models tried: ${MODELS[*]}"
    
    # Show truncated error output (last 500 chars to avoid flooding logs)
    if [ ${#last_error_output} -gt 500 ]; then
        log_error "Last error output (truncated): ...${last_error_output: -500}"
    else
        log_error "Last error output: $last_error_output"
    fi
    
    # Output the last error for debugging
    echo "$last_error_output"
    exit 1
}

# Run main with all script arguments
main "$@"