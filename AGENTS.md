# StoryTale Agent Working Agreement

This file is the shared operating contract for every coding agent working in
this repository, including Codex and Claude Code.

## Start here

1. Confirm the repository root and run `git status --short --branch` before
   proposing or making changes.
2. Read `docs/PROJECT_HANDOFF.md` for complete project context.
3. Read the current section of `docs/ROADMAP.md`. It is the only authority for
   phase status and development order.
4. Read only the plan owned by the current phase. Do not re-audit the entire
   repository unless the handoff is demonstrably inconsistent.
5. State the exact current phase, immediate acceptance gate, intended files,
   and validation plan before editing.

Do not copy phase status into this file. Phase status changes frequently and
must remain owned by the roadmap.

## Repository and agent coordination

- Preserve all pre-existing changes, including untracked files. Never use
  `git reset --hard`, destructive checkout, or broad cleanup to make the tree
  look clean.
- Make a checkpoint before a new implementation phase or risky refactor.
- Only one coding agent may edit a checkout at a time. If Codex and Claude must
  work concurrently, give each a separate Git worktree and branch.
- Do not force-push. Do not push, merge, open a pull request, or deploy unless
  the user explicitly requested that external action.
- Keep commits phase-scoped. Include only intended files and inspect the staged
  diff before committing.
- When implementation changes project status, update `docs/ROADMAP.md`,
  `docs/PROJECT_HANDOFF.md`, and the phase-owned plan in the same work unit.

## Product boundaries

- StoryTale is a local-first Flutter application and the MVP is EPUB-only.
- Do not introduce Supabase or another remote persistence service into the MVP.
- DeepL owns translation. Gemini owns semantic analysis. Cloudflare Workers AI
  owns generated backgrounds.
- **Image generation is provider-neutral by owner decision, 2026-08-07.** Sprite
  and character images go through the seam in
  `cloudflare/image-worker/src/providers/`, and the active provider is set by the
  `IMAGE_PROVIDER` var, not by code. Gemini is the current default. Adding
  another image provider is an adapter behind that interface, not a violation of
  this boundary. The Flutter app must stay unaware of which provider answered:
  it reads the `X-Image-Provider` header and never names one.
- Provider selection is configuration only. A client must never be able to
  choose the provider it is billed against, and a missing key or unknown
  provider name must fail loudly rather than fall back to a paid alternative.
- The versioned `humanoid_v1` head and nine body pieces are immutable runtime
  geometry. AI output must never replace or redraw that locked geometry.
- Do not add behavior specific to The Little Prince or any other fixture. All
  contracts must work for arbitrary imported EPUBs.
- A visible prototype is not proof that provider, persistence, or acceptance
  work is complete. Use the roadmap's exact gate.

## Paid providers and secrets

- Never read, print, edit, commit, or expose `.env`, `.env.flutter`,
  `.dev.vars`, credentials, tokens, or provider keys.
- Never make a paid/provider generation request without the user's explicit
  approval for that exact request.
- One approval permits one request only. Never retry a failed or rejected paid
  request automatically.
- Prefer fixtures, local contract checks, hashes, and dry validation until the
  owner explicitly approves live provider use.
- Never treat provider success alone as acceptance. Validate the complete
  package and owner-review gates recorded in the roadmap.

## Implementation and validation

- Keep changes small, simple, reusable, and phase-scoped.
- Use existing architecture and dependencies before adding a new abstraction
  or package.
- Run targeted automated validation proportional to the change. The project
  owner performs manual visual testing unless they explicitly delegate it.
- Do not start a persistent server or browser preview unless requested. If an
  agent starts one, it must report its URL and stop it when the task ends unless
  the user asks to keep it running.
- The canonical launcher is `tool/run_storytale.ps1`; the stable web preview
  port is `52827`.
- Do not mark a phase done while a documented acceptance gate remains pending.

## Required handoff at the end of a work unit

Before stopping:

1. Inspect `git diff` and `git status`.
2. Record status changes in the authoritative documents.
3. Report **Results**, **Validation**, **Missing work**, and **Next phase**.
4. Identify the exact commit and branch when a checkpoint was requested.
5. Leave the repository in a state the next agent can understand without
   relying on chat history.
