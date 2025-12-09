# MasuSenseiBot-Agent Codebase Analysis

## Executive Summary
MasuSenseiBot-Agent is a GitHub Actions-based AI automation tool designed to act as a "wise and patient mentor" for software projects. It uses the OpenCode CLI (`opencode`) to analyze issues, review pull requests, and perform compliance checks. The codebase consists primarily of GitHub Actions workflows (`.github/workflows/*.yml`) and markdown-based prompt templates (`.github/prompts/*.md`) that define the bot's persona and logic. There is no traditional application source code (e.g., Python or Node.js backend) beyond a utility script; the core logic resides in the prompts and shell scripts embedded within the workflow YAML files.

## 1. Project Structure Map

The project is structured as a GitHub Actions repository, with the majority of the logic contained within the `.github` directory.

```
c:/Repository/MasuSenseiBotV3-Agent/
├── .github/
│   ├── actions/
│   │   └── bot-setup/
│   │       └── action.yml        # Composite action for environment setup
│   ├── prompts/                  # AI Persona & Logic Definitions
│   │   ├── bot-reply.md          # Logic for @mentions and general interaction
│   │   ├── compliance-check.md   # Logic for PR compliance verification
│   │   ├── issue-comment.md      # Logic for analyzing new issues
│   │   └── pr-review.md          # Logic for code review
│   └── workflows/                # CI/CD Entry Points
│       ├── bot-reply.yml         # Triggered by issue_comment
│       ├── build.yml             # (Implied exists by compliance-check config, but not seen in list)
│       ├── cleanup.yml           # (Seen in file list)
│       ├── compliance-check.yml  # Triggered by PR events or manual dispatch
│       ├── issue-comment.yml     # Triggered by issues [opened]
│       ├── pr-review.yml         # Triggered by pull_request_target
│       └── status-check-init.yml # (Seen in file list)
├── docs/                         # Documentation directory (currently empty until this file)
├── .gitignore                    # Git ignore rules
├── LICENSE                       # MIT License
├── README.md                     # Main project documentation
└── minify_json_secret.py         # Utility script for config management
```

## 2. Existing Personality Configuration

The bot's personality is centrally defined in the markdown prompt files located in `.github/prompts/`.

### Core Persona: "Masu Sensei"
- **Role:** Wise and patient AI mentor / principal-level collaborator.
- **Tone:** Educational, supportive, constructive, humble, and guiding.
- **Key Traits:**
    - Focuses on "why" not just "what".
    - Uses phrases like "Let me guide you...", "Consider this approach...".
    - When reviewing its own code, adopts a "reflective, humble, and gently self-critical tone".
    - Avoids trivial nits; focuses on high-signal feedback.

### Configuration Locations
1.  **`.github/prompts/bot-reply.md`**:
    -   **Identity:** "You are **Masu Sensei**, a wise and patient AI mentor..."
    -   **Strategy:** Defines strategies like "The Conversationalist", "The Investigator", "The Code Reviewer", etc.

2.  **`.github/prompts/pr-review.md`**:
    -   **Role:** "AI code reviewer... As a sensei (teacher), you provide thoughtful, educational feedback..."
    -   **Self-Review Logic:** Explicit instructions for reviewing its own code with a "humorous, self-deprecating tone".

3.  **`.github/prompts/issue-comment.md`**:
    -   **Role:** "AI mentor specializing in bug triage... help the team understand the underlying principles."

4.  **`.github/prompts/compliance-check.md`**:
    -   **Role:** "AI compliance verification agent... guide teams toward maintaining high standards."

## 3. Technology Stack

-   **Platform:** GitHub Actions (Ubuntu runners).
-   **AI Engine:** `opencode` CLI (OpenCode) interacting with LLMs (OpenAI-compatible).
-   **Scripting:** Bash (embedded in YAML files).
-   **Data Processing:** `jq` for JSON manipulation.
-   **Version Control:** `git` and `gh` (GitHub CLI) for repository interaction.
-   **Configuration:** YAML (workflows), Markdown (prompts), JSON (provider config).

## 4. Entry Points & Workflows

The system is event-driven, triggered by GitHub webhook events.

| Workflow File | Trigger Event | Action |
| :--- | :--- | :--- |
| `issue-comment.yml` | `issues: [opened]` | Runs `opencode` with `issue-comment.md` to analyze bugs/features. |
| `pr-review.yml` | `pull_request_target`, `issue_comment` | Runs `opencode` with `pr-review.md` to review code. Generates diffs. |
| `compliance-check.yml` | `workflow_run`, `pull_request_target`, `issue_comment` | Runs `opencode` with `compliance-check.md` to verify file consistency. |
| `bot-reply.yml` | `issue_comment` (@mention) | Runs `opencode` with `bot-reply.md` to answer questions/commands. |

## 5. Integration Points for Personality

To improve or modify the bot's personality, changes should be focused on the **Markdown Prompt Files**:

1.  **`.github/prompts/bot-reply.md`**:
    -   Modify `[ROLE & OBJECTIVE]` and `[Your Identity]` sections.
    -   Adjust specific response templates in the `[COMPREHENSIVE STRATEGIES]` section.

2.  **`.github/prompts/pr-review.md`**:
    -   Modify `[ROLE & IDENTITY]` to adjust the "Sensei" tone.
    -   Update the "Special Instructions: Reviewing Your Own Code" section.

3.  **`.github/prompts/issue-comment.md`**:
    -   Modify the educational approach in `[ROLE & OBJECTIVE]`.

4.  **`.github/prompts/compliance-check.md`**:
    -   Adjust the feedback style in `[ROLE & IDENTITY]`.

No changes to the `.yml` workflow files are strictly necessary to alter personality, unless new inputs or environment variables are needed to support a new capability.

## 6. GitHub Actions & Automation

-   **`.github/actions/bot-setup/action.yml`**: A composite action that handles:
    -   GitHub App token generation.
    -   Git user configuration (`masusenseibot-agent[bot]`).
    -   OpenCode CLI installation and configuration (`~/.config/opencode/opencode.json`).
    -   Python/uv setup (if `requirements.txt` exists).
-   **Workflows**: Heavily rely on `envsubst` to inject dynamic context (diffs, JSON data) into the markdown prompts before passing them to `opencode run`.
-   **Security**: Workflows use `pull_request_target` to run from the base branch context, preventing prompt injection from untrusted PRs (by copying trusted prompts from the base branch).