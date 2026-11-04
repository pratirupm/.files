<!-- deepseek-flash-orchestrator:begin -->
## Shared rules

- Primary managers: `planner` (research + plan) and `builder` (implementation). The built-in `plan` and `build` modes are hidden.
- `planner` is read-only; it hands implementation requests to `builder` and never attempts edits or `worker` launches.
- Subagents: `mechanical` (local read-only), `scout` (web/local research), `worker` (edits). They are leaf agents: never delegate.
- Every subagent launch must run in background (`background: true`, enforced by the force-background plugin).
- All agents use `opencode-go/deepseek-v4.1-flash`. If the Go allowance fails, stop and report; do not downgrade.
- Never print secrets; do not bulk-reformat; file operations only on explicitly named paths.
<!-- deepseek-flash-orchestrator:end -->
