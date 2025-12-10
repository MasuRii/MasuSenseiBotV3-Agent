# Codebase Analysis: Model Configuration & Priority Logic

## Executive Summary
The current codebase relies on the `OPENCODE_MODEL` secret as the single source of truth for the primary model identifier. While `CUSTOM_PROVIDERS_JSON` allows defining custom model configurations, it is currently only used to validate or configure the provider for the explicitly defined `OPENCODE_MODEL`. There is no logic to automatically select a model from `CUSTOM_PROVIDERS_JSON` if `OPENCODE_MODEL` refers to a default or incompatible value. This creates a "conflict" where users must manually synchronize `OPENCODE_MODEL` with their custom provider definitions, leading to potential configuration errors or unintended fallback to default providers.

## 1. Relevant Files

The following files are central to the model configuration and selection logic:

*   **Action Definition**: `.github/actions/bot-setup/action.yml`
*   **Workflows (Consumers)**:
    *   `.github/workflows/bot-reply.yml`
    *   `.github/workflows/issue-comment.yml`
    *   `.github/workflows/pr-review.yml`
    *   `.github/workflows/compliance-check.yml`
*   **Helper Script**: `.github/scripts/run-with-fallback.sh`
*   **Configuration**: `custom_providers.json` (Example/Template)

## 2. Current Implementation

### 2.1 `CUSTOM_PROVIDERS_JSON` Usage

This secret is passed into the `bot-setup` action and used to generate the `~/.config/opencode/opencode.json` configuration file.

**File**: `.github/actions/bot-setup/action.yml`
**Lines**: 98-107 (Merging custom providers)
```bash
        # --- INITIAL CONFIG SETUP ---
        mkdir -p ~/.config/opencode
        CONFIG='{"$schema": "https://opencode.ai/config.json", "username": "masusenseibot-agent", "autoupdate": true}'

        # Merge custom provider definitions if they are not the empty default
        if [ "$CUSTOM_PROVIDERS" != "{}" ]; then
          echo "Custom provider definitions found. Merging into configuration."
          CONFIG=$(jq --argjson customProviders "$CUSTOM_PROVIDERS" '. * {provider: $customProviders}' <<< "$CONFIG")
        else
          echo "No custom provider definitions supplied."
        fi
```

### 2.2 `OPENCODE_MODEL` Usage

The `OPENCODE_MODEL` secret is a **required** input for the `bot-setup` action and is assigned to the `MAIN_MODEL` variable. It dictates which model is configured in the generated config file.

**File**: `.github/actions/bot-setup/action.yml`
**Lines**: 70 & 155
```bash
        MAIN_MODEL="${INPUT_MAIN_MODEL}"
        # ...
        configure_model "$MAIN_MODEL" "model"
```

### 2.3 Conflict & Logic Flow

The logic in `configure_model` (Lines 110-152 of `action.yml`) determines how the model is configured. The conflict arises because the script **always** attempts to configure `MAIN_MODEL` (derived from `OPENCODE_MODEL`), regardless of whether `CUSTOM_PROVIDERS_JSON` dictates a different preference.

**Conflict Logic (Lines 118-126):**
```bash
          # Check if the provider exists in the custom definitions
          if jq -e --arg provider "$provider" '. | has($provider)' <<< "$CUSTOM_PROVIDERS" >/dev/null; then
            echo "Provider found in custom definitions."

            # CASE 2: Provider exists, but the model does not. This is an error.
            if ! jq -e --arg provider "$provider" --arg modelName "$model_name" '.[$provider].models | has($modelName)' <<< "$CUSTOM_PROVIDERS" >/dev/null; then
              echo "::error::Configuration error: Provider is defined, but model is not found within it. Aborting."
              exit 1
            fi
```

**Scenario causing conflict:**
1. User defines `CUSTOM_PROVIDERS_JSON` with a custom provider (e.g., `my-proxy`) and a model (e.g., `llama-3`).
2. User leaves `OPENCODE_MODEL` as the default `openai/gpt-4o` (or forgets to update it to `my-proxy/llama-3`).
3. The script executes `configure_model "openai/gpt-4o"`.
4. It checks `CUSTOM_PROVIDERS`. If `openai` is NOT in `CUSTOM_PROVIDERS`, it falls through to "Case 3" (Line 133) and configures `openai/gpt-4o` as a standard provider using `DEFAULT_API_KEY`.
5. **Result**: The bot uses `openai/gpt-4o` instead of the user's intended custom model `my-proxy/llama-3`. The custom provider configuration is ignored for the main model selection.

## 3. Fallback Mechanisms

Existing fallback logic is handled in `bot-setup/action.yml` (Lines 167-219) and executed by `.github/scripts/run-with-fallback.sh`.

**Logic:**
It identifies fallback models **only** if they belong to the same provider as `OPENCODE_MODEL`.

**File**: `.github/actions/bot-setup/action.yml`
**Lines**: 189-193
```bash
        # Check if the provider exists in custom providers
        if ! echo "$INPUT_CUSTOM_PROVIDERS" | jq -e --arg provider "$PROVIDER" 'has($provider)' >/dev/null 2>&1; then
          echo "Provider '$PROVIDER' not found in custom providers. Using only primary model."
          echo "models=$INPUT_MAIN_MODEL" >> $GITHUB_OUTPUT
          exit 0
        fi
```

This reinforces the conflict: if `OPENCODE_MODEL` points to a standard provider (like `openai`) but the user intended to use a custom provider, the fallback logic effectively disables itself because the standard provider isn't in `CUSTOM_PROVIDERS`.

## 4. Conclusion

The codebase currently treats `OPENCODE_MODEL` as the absolute directive for model selection. `CUSTOM_PROVIDERS_JSON` is passive configuration data. To resolve the conflict, the `bot-setup` action needs logic to prioritize a model defined in `CUSTOM_PROVIDERS_JSON` (if valid) over the `OPENCODE_MODEL` input, or allow `OPENCODE_MODEL` to be optional/inferred when custom providers are present.