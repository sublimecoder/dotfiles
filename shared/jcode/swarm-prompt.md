# ⚙️ Effort table — task type → model (swarm/subagent dispatch)

> **Inline mirror of `~/code/aios-vault/AIOS/Systems/effort-table.md`.**
> jcode ignores `~/.claude/CLAUDE.md` and does not follow `@import`, so this file
> exists to carry the effort table into jcode's swarm/subagent dispatches. **The
> vault file is canonical — edit tiers there, then re-mirror here.**
> `AIOS/Systems/aios-check.sh` reports this file missing.
> Mirrored 2026-09-06 from the vault copy.

**The one place model names live.** Layer-neutral infra: pure model routing, no
creator/professional/work identity content — so it is safe to load into *every*
dispatch without crossing the identity wall. **"employer" is deliberately generic** —
it means any organization in the work layer, of which there may be more than one.

| Task type | Effort | Model | ID |
|---|---|---|---|
| **Default — everything not routed elsewhere** | high | **Opus 5.5** | `claude-opus-5-5` |
| Hardest judgment calls: irreversible, published, security- or money-critical, cross-layer | xhigh | Fable 5.1 | `claude-fable-5-1` |
| Mid-weight drafting / analysis / bulk edits in a subagent | medium | Sonnet 5.5 | `claude-sonnet-5-5` |
| Mechanical scans, greps, per-item grunt work | low | Haiku 5.5 | `claude-haiku-5-5` |

*Effort* = reasoning-effort dial (low/medium/high/xhigh/max) to set per dispatch.

**Dispatch rules**
- Pick the row by **task type**, not by how large the task feels. A big mechanical
  scan is still `low`; a small irreversible decision is still `xhigh`.
- One identity layer per subagent invocation — never hand one agent two layers.
- Read-heavy scans, audits and per-item grunt work are exactly what to delegate;
  judgment that needs the identity wall stays in the orchestrator.
- Change a model or tier in the **vault** file only — this mirror inherits it.
- Keep this file layer-neutral. No identity content ever, or the mirror breaches the wall.
