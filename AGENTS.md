# DIT Renamer Agent Collaboration Contract

This file is the shared operating contract for Codex, Antigravity, and any
other agent working in this repository.

## Project scope

- Application source: `src/` and `src_swift/`
- Web UI: `src/web/`
- Operational documentation: `docs/`
- Agent skills and shared coordination records: `.agents/`
- Build and release outputs: `build/`, `build_swift/`, and `Release/`

## Before editing

1. Read this file and any more-specific `AGENTS.md` in the target directory.
2. Read relevant files under `.agents/skills/` when the task concerns DIT,
   storage, camera media, or field operations.
3. Run `git status --short --branch` and preserve all existing user changes.
4. Do not assume an untracked file is disposable. Inspect it before changing
   or excluding it.

## Change safety

- Never run `git reset --hard`, `git checkout --`, `git clean`, force-push, or
  an equivalent destructive rollback without explicit user approval.
- Do not overwrite, delete, or revert another agent's uncommitted work.
- Do not commit secrets, virtual environments, caches, or generated packages.
- Treat camera-card and mounted-volume operations as high risk. Prefer dry-run
  or read-only inspection and require explicit confirmation before destructive
  filesystem operations.

## Branch and commit protocol

- One task gets one branch. Recommended names:
  `codex/<short-task>`, `antigravity/<short-task>`, or `agent/<short-task>`.
- Keep `main` as the shared integration branch.
- Make small, coherent commits. Do not rewrite shared history.
- Commit subject prefixes identify the authoring agent:
  `[agent]`, `[antigravity]`, or `[agent]`.
- Every completed task must update `.agents/CHANGELOG.md` with the commit,
  affected areas, validation performed, and any follow-up risk.

## Handoff protocol

Before handing work to another agent:

1. Commit or clearly list every intentional uncommitted change.
2. Update `.agents/HANDOFF.md` with current branch, commit, task state, tests,
   and known risks.
3. State whether the next agent may edit, test, build, or merge.

## Validation

At minimum, run syntax/static checks relevant to the files changed. For
application behavior, prefer a focused test or dry-run before a full build.
Record the exact validation command in `.agents/CHANGELOG.md`.

