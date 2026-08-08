# Current Agent Handoff

## State

- Owner: Codex
- Branch: `main`
- Status: Collaboration structure established; baseline committed
- Last commit: `f8d26d4` (`collab-baseline-20260808`)

## Working agreement

- Existing application changes are intentional working material and must be
  preserved.
- `Release/`, `build_swift/`, `build/`, and `.venv` are local/generated assets;
  do not use them as source-of-truth inputs for code changes.
- Before another agent edits, it should read `AGENTS.md`, this file, and the
  latest `.agents/CHANGELOG.md` entry.

## Next handoff

Next agent should create a task branch from `main`, update this file with the
active task, validation results, and whether merging into `main` is permitted.
