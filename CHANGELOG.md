# Changelog

## 0.2.0 — 2026-11-01

- Add a single-process SQLite runtime with a durable event inbox, reusable
  completed step checkpoints, and an ordinary reply outbox. Use WAL, FULL
  synchronization, a private database file, and a process lock.
- Process up to three conversations concurrently by default while keeping each
  profile/conversation lane serial. Add `--max-workers`, `--runtime-db`, and
  read-only `--runtime-status`; preserve queued work during shutdown.
- Recover interrupted jobs to the queue, guard uncertain execution and delivery
  as `unknown`, and block queued work after authorization changes. Unknown
  results require manual authoritative reconciliation; no recovery CLI is
  included in this release.
- Retain multiple owner approval requests per group, accept explicit task IDs,
  reuse recorded execution for later delivery, and read legacy approval files.
  Require whole confirmation phrases rather than substring matches.
- Require explicit `code_write_policy=auto` for ordinary autofix; keep approval
  gates for both reply engines. Run autofix in a separate worktree with host
  verification and explicitly request read-only sandboxing for resumed group
  reply sessions.
- Keep an uncertain optional ready greeting from blocking inbox startup, while
  preserving its checkpoint for manual reconciliation.
- Add GitHub Actions checks on Python 3.10 and 3.13. Each job installs the
  standalone package, runs the unit tests, and validates the safe sample
  configuration without starting a listener or sending messages.
- Keep the package metadata and exported `__version__` at `0.2.0`.
- Document the inspiration from the official DeepSeek SuperAgent research
  prototype and the implemented scope, sandbox, recovery, and evidence limits.

## 0.1.0

- Initial standalone release of the DingTalk personal-message worker and
  configuration TUI.
