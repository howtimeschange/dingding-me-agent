# Agent Guide

## Project

`dingding-me-agent` is a Python 3.10+ service that consumes personal DingTalk
IM events through the DWS CLI, applies strict group/policy gates, and can run
persistent Codex sessions or explicitly approved worktree tasks.

## Navigation

- `src/dingding_me_agent/worker.py`: event lifecycle, DWS subprocess adapter,
  classification, Codex, approvals, worktrees, and state.
- `src/dingding_me_agent/config_tui.py`: terminal-only configuration editor.
- `config/agent-config.example.json`: safe sample configuration; never put real
  group IDs, credentials, or repository paths here.
- `docs/`: operating guide and state-machine specification.
- `service/`: placeholder-only launchd and systemd templates.
- `tests/`: unit tests for the worker and configuration editor.

## Commands

- Test: `make test`
- Compile + test: `make check`
- Validate the sample configuration: `make config-check`
- Local editable install: `python3 -m pip install -e .`

## Working Rules

- Preserve `draft` as the non-sending default. Do not widen send targets,
  repositories, or approval identities implicitly.
- DWS is an external CLI contract: retain flattened NDJSON consumption and JSON
  chat read/send calls. Do not replace the event connection with history polling.
- Treat Codex execution, Git worktree creation, tests, commits, pushes,
  deployments, and production reads as independent states. This service never
  commits, pushes, deploys, or publishes automatically.
- Runtime state belongs in `~/.dingding-me-agent/` (or
  `DINGDING_ME_AGENT_HOME`), never in the repository. Do not read or mutate a
  real user's live config or LaunchAgent unless explicitly requested.

## Verification

Run `make check` after source changes. For configuration semantics, also run
`make config-check`. Service templates are templates only; validate an
installed instance separately and never claim listener health from a local test.
