@AGENTS.md

# Claude Code entry point

- Work from the repository root that contains this file.
- Begin every new session by reading `docs/PROJECT_HANDOFF.md`, then the current
  section of `docs/ROADMAP.md`, then only the plan owned by that phase.
- Use Plan Mode for complex, multi-file, architectural, provider, persistence,
  or migration work. Present a reviewable plan before editing.
- Do not import the complete handoff or roadmap into this file; loading them on
  demand keeps the startup context and subscription usage smaller.
- Use normal permission prompts. Never request or recommend bypass-permissions
  or auto-approval modes for this repository.
- Before handing work back, refresh the handoff documents when status changed,
  inspect the final diff, and give the user the exact next safe prompt.
