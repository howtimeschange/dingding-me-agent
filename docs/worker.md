# Dingding Me Agent Worker 0.2.0

The worker consumes personal DingTalk events using the logged-in DWS user. It
retains per-group Codex CLI sessions and can prepare locally verified code
changes under explicit policy gates. It does not commit, push, merge, deploy,
or publish automatically.

See [README](../README.md) for installation, configuration fields, environment
precedence, and the configuration TUI. See [runtime recovery](runtime-recovery.md)
for interrupted work and unknown delivery outcomes.

## Entry points and configuration

```bash
dingding-me-agent --config /ABS/PATH/TO/config.json --config-check
dingding-me-agent-config --config /ABS/PATH/TO/config.json --validate
```

These checks do not start a listener, send messages, or invoke Codex. By
contrast, `--print-command` prints the listener command and then starts the
service. The configuration TUI saves atomically with a backup; it does not
start or restart the service.

The safe sample is [agent-config.example.json](../config/agent-config.example.json).
Keep actual IDs, repositories, skills, tokens, and state outside the checkout.
The default state root is `~/.dingding-me-agent/`, overridable through
`DINGDING_ME_AGENT_HOME`. DWS login remains managed by DWS.

## Intake and dispatch

The transport is `dws event consume ... --flatten -f ndjson`, with the child's
stdin kept open until shutdown. History reads can supply recent context; they
do not replace the event stream.

- A group trigger uses a group-message listener.
- A mention trigger uses an @ listener and a local conversation admission gate.
- Mention plus approval policy adds a group-message listener for owner
  confirmations. Ordinary unmentioned messages on that listener do not create
  normal reply requests.
- Receive type and conversation admission are checked before runtime enqueue.
  Both listener routes share the conversation lane and durable message identity.
- The default worker pool processes up to three conversations concurrently.
  One conversation, scoped by DWS profile, remains serial within this process.

```bash
# Starts a service; use only with an authorized runtime configuration.
dingding-me-agent --config /ABS/PATH/TO/config.json --max-workers 3
```

`--max-workers` accepts 1–32. This is single-process, bounded thread scheduling,
not a distributed agent cluster or a task-per-Codex-session implementation.

## Mode and execution boundaries

| Mode / path | Model behavior | Code behavior |
| --- | --- | --- |
| `observe` | Classifies, then stops; the configured classifier can use AI | No Codex execution or reply generation |
| `draft` | AI drafts or a persistent Codex session generates a local draft | General bridge prepares tasks without executing them |
| `guarded` | Replies only when `send=true`; general code review also requires `codex_execute=true` | General review requests `read-only` |
| `autofix` | Requires `code_write_policy=auto`, an explicit low-risk BUG, confidence threshold, repo, tests, and execution flag | Creates a separate worktree, requests `workspace-write`, then runs host tests |
| Owner-approved code task | Requires approval policy, configured owner, matching authorization, and `codex_execute=true` | Creates a separate worktree and requests `workspace-write`; does not additionally require `mode=autofix` |

`draft` suppresses sending but does not suppress Codex session generation when
`reply_engine=codex`. The approval-confirmation route runs before ordinary
mode-based feedback processing: use `code_write_policy=none` or
`codex_execute=false` when local code changes must be disabled.

The default write policy `none` also blocks ordinary autofix. With `approval`,
both AI and Codex reply engines save a pending request before code execution;
autofix mode does not bypass that approval.

New and resumed group reply sessions explicitly request the Codex CLI's
`read-only` sandbox. Code-change tasks request `workspace-write`. The host runs
configured `test_commands` through a shell in the task worktree, outside that
Codex sandbox. The worker does not implement a separate OS sandbox.

Autofix and approved tasks retain `worktree.json`, Codex logs, and host
`verification.json`. Configured test failure makes the result failed. An
approved task with no configured tests cannot claim test verification merely
because Codex exits zero. A zero exit or a model's `FIXED` text is not evidence
of a deployed fix.

## Persistent state

By default:

```text
~/.dingding-me-agent/
  config.json
  seen.jsonl
  seen.sqlite3
  seen.sqlite3.lock
  codex-sessions/<conversation>/
  codex-tasks/<task>/
  pending-approvals/<group>.json
  worktrees/<task>/
```

`--runtime-db` selects a different SQLite path. Otherwise the path is
`Path(state_file).with_suffix(".sqlite3")`: changing `--state-file` also changes
the default runtime database. The lock protects that database path only.

The runtime stores inbox jobs, step checkpoints, and ordinary reply outbox
records in SQLite with WAL, `synchronous=FULL`, and a `0600` database file.
Legacy `seen.jsonl` remains an input to duplicate suppression. Session and task
artifacts remain separate files, not database-backed conversation memory.

Completed steps are reused. Interrupted started steps become `unknown` on
restart; sending outbox records also become `unknown`. They require manual
reconciliation and are not replayed automatically. Running jobs return to the
queue, but their uncertain steps still prevent re-execution. Queued jobs whose
registered policy changed are blocked. Missing routes are also blocked.

Stopping intake preserves queued jobs. Shutdown does not start the remaining
backlog; already-running work may finish while the process waits. A forced
termination leaves recovery guards for the next startup.

## Owner approval

One group can retain several pending requests. Use the ID printed in the reply:

```text
确认 dws-codex-0123456789abcdef0123
```

Plain confirmation phrases such as `OK` work only for a unique pending request.
Multiple requests require selection. The owner allowlist fails closed when
empty, and display names do not confer authority. The saved authorization
snapshot must still match the current policy. Legacy single-request approval
files remain readable; their stored group/project/repo scope is checked.

Confirmation must consist of whole configured phrases, optionally combined
(for example, `好的，继续`) and a task ID. A negation such as `不确认` or a
question such as `确认一下原因` does not grant approval.

Repeated handling does not renew the original approval TTL. An already-recorded
execution checkpoint is not discarded solely because delivery crossed that
TTL: completed execution is reused, and uncertain execution stays guarded.
Approval delivery identity belongs to the task, so later confirmations do not
create a fresh delivery identity. Pending approval is cleared after delivery
returns, rather than before the delivery attempt.

## Status and observability

```bash
dingding-me-agent --runtime-status
dingding-me-agent --runtime-db /ABS/PATH/TO/runtime.sqlite3 --runtime-status
```

Status opens an existing database read-only, prints counts for jobs/steps/outbox
and attention job IDs, and exits. It does not connect DWS, acquire the service
lock, migrate tables, reconcile unknown rows, or approve retries.

Worker stdout contains JSON actions such as `runtime_opened`, `runtime_ready`,
`runtime_attention_required`, classification, and delivery results. Optional
`codex_audit_session_dir` mirrors prompts, outputs, and session metadata for
human inspection. Logs and mirrors can contain private business context.

Listener `ready` / `connected`, optional `ready_message`, actual reply delivery,
code execution, local tests, and remote deployment are separate evidence.
An uncertain optional greeting records `ready_message_attention_required` and
does not prevent inbox startup; its checkpoint still blocks automatic replay.

## Verification and reference

```bash
make check
make config-check
git diff --check
```

These are local checks. They do not establish installed service health or
production delivery. The GitHub Actions matrix covers Python 3.10 and 3.13.

The persistence and scheduling changes draw on DeepSeek's official research
prototype [dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype).
This worker retains DWS and Codex CLI; it has no DSH execution dependency,
complete Ticket/Assignment subscription model, PR lifecycle, or Web dashboard.
