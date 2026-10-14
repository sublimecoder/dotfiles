# ⚙️ Effort table — task type → model

> **Inline mirror of `~/code/aios-vault/AIOS/Systems/effort-table.md`.**
> jcode ignores `~/.claude/CLAUDE.md` and does not follow `@import`, so this file
> exists to carry the effort table into jcode sessions. **The vault file is
> canonical — edit tiers there, then re-mirror here.** `AIOS/Systems/aios-check.sh`
> reports this file missing.
> Mirrored 2026-09-06 from the vault copy.

**The one place model names live.** Layer-neutral infra: pure model routing, no
creator/professional/work identity content — so it is safe to load into *every*
session (personal, creator, employer, unrelated coding) without crossing the
identity wall. **"employer" is deliberately generic** — it means any organization in
the work layer, of which there may be more than one.

| Task type | Effort | Model | ID |
|---|---|---|---|
| **Default — everything not routed elsewhere** | high | **Opus 5.5** | `claude-opus-5-5` |
| Hardest judgment calls: irreversible, published, security- or money-critical, cross-layer | xhigh | Fable 5.1 | `claude-fable-5-1` |
| Mid-weight drafting / analysis / bulk edits in a subagent | medium | Sonnet 5.5 | `claude-sonnet-5-5` |
| Mechanical scans, greps, per-item grunt work | low | Haiku 5.5 | `claude-haiku-5-5` |

*Effort* = reasoning-effort dial (low/medium/high/xhigh/max) to set per Agent/Workflow dispatch.

**Default is set once, globally.** `~/.claude/settings.json` carries `"model": "opus[1m]"`
(latest Opus, 1M-context variant) and `"effortLevel": "high"`. No repo `.claude/settings.json`
pins a model — they all inherit. Escalation to Fable and downgrades to Sonnet/Haiku are
per-dispatch decisions off this table, not per-repo config.

Bindings: `.claude/agents/*.md` frontmatter carries `model:` + `effort:` per this table
(family aliases `opus`/`sonnet`/`haiku` resolve to the latest of that family); portable
`skills/*/SKILL.md` may carry `effort:` (published-output skills pin `high`); commands and
vault-note skills stay unpinned — they inherit the orchestrator session model.

**Editing rules**
- Change a model or tier in the **vault** file only — every consumer, including this
  mirror, inherits it.
- Changing the default means editing `~/.claude/settings.json` `model` **and** the default
  row in the vault file. Do not re-introduce per-repo `model` pins.
- A repo may override a row in its own `CLAUDE.md`.
- Keep this file layer-neutral. No identity content ever, or the mirror breaches the wall.

---

# 🧠 AIOS brain — jcode adaptation

> **Adapted from `~/code/aios-vault/AIOS/Systems/repo-aios-block.md`** (the usage
> rules Claude Code's SessionStart hook injects into every wired repo; each repo's
> `AGENTS.md` also points to it). jcode's `session_start` hook is a detached observer
> whose stdout never reaches the model, so the "header injected at session start"
> mechanism cannot work here. Under jcode the brain is **pulled**, not pushed.
> Layer-neutral: names no identity. Added 2026-10-13; updated 2026-10-13 for the
> hook-injected block and playbook.

**Before any non-trivial task in a repo, load its brain:**

    cd <repo root> && AIOS_NOTE_HOOK=1 sh ~/code/aios-vault/AIOS/Systems/hooks/aios-context.sh && sh ~/code/aios-vault/AIOS/Systems/hooks/aios-context.sh --note

- It looks the repo up in `AIOS/Systems/repo-layers.tsv`. The first call prints
  `=== AIOS brain (<layer>/<project>) ===` with the usage rules
  (`repo-aios-block.md`), `<layer>/me.md` (durable) and `<layer>/playbook.md` when
  the layer has one, and syncs the vault (pull/push) first. The second prints the
  project note's current state under `… — project note ===`. Run both: the split
  gives each its own 10,000-byte budget, so a long note is not cut to fit.
- A section ending `… (cut for size at N bytes; full: <path>)` was trimmed; read
  that path when the task touches it.
- **No output = the repo is not in `repo-layers.tsv`.** Say so; do not go hunting
  through the vault for a match. An unwired vault looks exactly like an empty one.
- The project note records what the code cannot: why it was built this way, what
  already failed, corrections already given. Read the full note
  (`~/code/aios-vault/<layer>/projects/<project>.md`) when the excerpt is not enough.

**Identity wall.** Read only the layer that lookup names. Never read another
layer's vault notes into this session's output, and never carry employer-proprietary
detail into a public-brand repo. Do not run `aios-session-status.sh` or read
`AIOS/History/Log.md` / `Home.md` from a project repo: they mix all layers.

**Write back** a durable fact (decision, preference, gotcha, correction) to the vault,
not the repo. If you write a vault file directly, commit exactly those paths before
stopping: `git -C ~/code/aios-vault add <path>... && git -C ~/code/aios-vault commit -m '<layer>/<project>: <what>' -- <path>...`
Pathspec only, never `git add -A`: other sessions share that tree.
