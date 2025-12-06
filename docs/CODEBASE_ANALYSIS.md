# Codebase Analysis: Mirrobot-Agent

## Executive Summary

This repository contains "Mirrobot-Agent", a production-ready AI GitHub bot powered by GitHub Actions and OpenCode. It is designed to automate issue analysis, PR reviews, and provide intelligent assistance through comments. The codebase is primarily composed of GitHub Actions workflows (`.yml`) and markdown prompt templates (`.md`) that define the AI's behavior and personality. The bot's logic is orchestrated via workflows that trigger on specific GitHub events (issues, PRs, comments), utilizing the `opencode` CLI tool to execute AI-driven tasks. The core identity "Mirrobot" or "mirrobot-agent" is deeply embedded in the workflows and prompt files, making these the primary targets for customization.

## 1. Project Structure Overview

The project follows a standard GitHub Actions repository structure:

- **Root Directory**:
    - `README.md`: Comprehensive documentation covering features, installation, architecture, and usage.
    - `minify_json_secret.py`: A Python utility script for minifying JSON configuration for GitHub secrets.
    - `LICENSE`: MIT License file.
- **`.github/` Directory**:
    - `workflows/`: Contains the YAML definition files for GitHub Actions. These are the entry points for the bot's functionality.
    - `prompts/`: Contains the Markdown files used as system prompts for the AI. These define the bot's role, identity, constraints, and operational logic.
    - `actions/bot-setup/`: Contains a composite action (`action.yml`) for initializing the bot environment (setup steps).

### Technology Stack
- **Orchestration**: GitHub Actions (YAML)
- **AI Engine**: OpenCode (via `opencode` CLI in workflows)
- **Scripting**: Bash (embedded in YAML steps), Python (`minify_json_secret.py`), jq (JSON processing)
- **Configuration**: GitHub Secrets, Environment Variables

## 2. Core Workflows & Entry Points

The application logic is driven by five main workflows located in `.github/workflows/`:

1.  **`bot-reply.yml`**:
    -   **Trigger**: `issue_comment` (created) containing `@mirrobot` or `@mirrobot-agent`.
    -   **Function**: Handles user interactions in issues and PRs. It gathers context and invokes the `bot-reply.md` prompt.
    -   **Key Identity Reference**: Lines 9, 18 (env `BOT_NAMES_JSON`).

2.  **`compliance-check.yml`**:
    -   **Trigger**: `workflow_run` (after PR Review), `pull_request_target` (labeled), `issue_comment` (commands), `workflow_dispatch`.
    -   **Function**: Verifies PRs for file consistency and documentation updates. Uses `compliance-check.md` prompt.
    -   **Key Identity Reference**: Lines 74-75 (commands), Line 90 (env `BOT_NAMES_JSON`).

3.  **`issue-comment.yml`**:
    -   **Trigger**: `issues` (opened), `workflow_dispatch`.
    -   **Function**: Analyzes new issues for duplicates and root causes. Uses `issue-comment.md` prompt.
    -   **Key Identity Reference**: Uses `bot-setup` action.

4.  **`pr-review.yml`**:
    -   **Trigger**: `pull_request_target`, `issue_comment` (commands), `workflow_dispatch`.
    -   **Function**: Performs code reviews on PRs. Uses `pr-review.md` prompt.
    -   **Key Identity Reference**: Lines 29 (commands), Line 38 (env `BOT_NAMES_JSON`).

5.  **`status-check-init.yml`**:
    -   **Trigger**: `pull_request_target`.
    -   **Function**: Sets initial pending status for compliance checks.

## 3. Bot Name & Personality References

The bot's identity is defined in two main ways: **System Identifiers** (used in logic/filtering) and **Persona Definitions** (used in AI prompts).

### System Identifiers (Logic & filtering)
These references control how the bot recognizes itself to avoid loops (e.g., ignoring its own comments) and how users invoke it.

| File Path | Line(s) | Context |
| :--- | :--- | :--- |
| `.github/workflows/bot-reply.yml` | 9 | `if: ${{ contains(github.event.comment.body, '@mirrobot') ...` |
| `.github/workflows/bot-reply.yml` | 18 | `BOT_NAMES_JSON: '["mirrobot", "mirrobot-agent", "mirrobot-agent[bot]"]'` |
| `.github/workflows/compliance-check.yml` | 74-75 | `contains(github.event.comment.body, '/mirrobot-check')` |
| `.github/workflows/compliance-check.yml` | 90 | `BOT_NAMES_JSON: '["mirrobot", "mirrobot-agent", "mirrobot-agent[bot]"]'` |
| `.github/workflows/pr-review.yml` | 29 | `contains(github.event.comment.body, '/mirrobot-review')` |
| `.github/workflows/pr-review.yml` | 38 | `BOT_NAMES_JSON: '["mirrobot", "mirrobot-agent", "mirrobot-agent[bot]"]'` |

### Persona Definitions (Prompts)
These files instruct the AI on who it is and how to behave.

| File Path | Line(s) | Context |
| :--- | :--- | :--- |
| `.github/prompts/bot-reply.md` | 6 | `You operate under the names **mirrobot**, **mirrobot-agent**...` |
| `.github/prompts/compliance-check.md` | 7 | `You operate as **mirrobot-agent**.` |
| `.github/prompts/issue-comment.md` | 5 | `You operate under the names **mirrobot**, **mirrobot-agent**...` |
| `.github/prompts/pr-review.md` | 7 | `You operate under the names **mirrobot**, **mirrobot-agent**...` |

### Documentation References
The `README.md` is heavily branded with "Mirrobot Agent".

- **Title**: Line 1 ("Mirrobot Agent")
- **Descriptions**: Lines 12, 14, 125, etc.
- **Commands**: Lines 227 (`@mirrobot-agent`), 270 (`/mirrobot-review`), 310 (`/mirrobot-check`).

## 4. Recommended Customization Points

To rename the bot to "MasuSenseiBot-Agent" and adopt the new personality, the following changes are required:

1.  **Workflows (`.github/workflows/*.yml`)**:
    -   Update `BOT_NAMES_JSON` variable in all workflows.
    -   Update trigger conditions (`if` clauses) checking for mentions (`@mirrobot`) and slash commands (`/mirrobot-check`, etc).
    -   Update any hardcoded command strings in comments or descriptions.

2.  **Prompts (`.github/prompts/*.md`)**:
    -   **Identity Sections**: Rewrite the `[Your Identity]` or `[ROLE & IDENTITY]` sections to define "MasuSenseiBot-Agent".
    -   **Personality/Tone**:
        -   *Current*: Professional, helpful, occasionally humorous/self-deprecating (specifically in self-reviews).
        -   *Target*: "MasuSensei" personality (needs specific definition from user, assuming "Sensei" implies a teacher/mentor tone).
    -   **Example Commands**: Update example commands in the prompts to match the new name.

3.  **Documentation (`README.md`)**:
    -   Replace "Mirrobot Agent" with "MasuSenseiBot-Agent".
    -   Update installation instructions and command references.

## 5. Running & Testing

Since this is a GitHub Actions-based bot, "running" it implies deploying it to a GitHub repository.

-   **Installation**: Fork repo or copy `.github/` to a target repo.
-   **Configuration**: Set required secrets (`BOT_APP_ID`, `BOT_PRIVATE_KEY`, `OPENCODE_API_KEY`, etc.) in the target repo.
-   **Testing**:
    -   Create an issue/PR in the target repo.
    -   Trigger workflows via comments (e.g., `@MasuSenseiBot-Agent help`) or manual dispatch.
    -   The `test-config.py` script (mentioned in README but not found in file list, possibly missing or I missed it in the initial recursive list?) can verify provider config. *Correction: `test-config.py` was listed in the README content but was not present in the initial file listing of the current directory.*
