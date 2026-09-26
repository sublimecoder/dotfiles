@~/.claude/RTK.md

## Machine-wide doctrine
Canonical in the AIOS vault (`~/code/aios-vault/AIOS/Systems/`), layer-neutral, no private content. Edit each rule in its own file only; history lives in `doctrine-changelog.md` there, which is not imported.

@~/code/aios-vault/AIOS/Systems/effort-table.md
@~/code/aios-vault/AIOS/Systems/reasoning-doctrine.md
@~/code/aios-vault/AIOS/Systems/ponytail-amendment.md
@~/code/aios-vault/AIOS/Systems/plan-recon-amendment.md
@~/code/aios-vault/AIOS/Systems/tmp-is-ram.md

## AIOS brain vault
The AIOS brain vault lives at `~/code/aios-vault` (run `claude` from there, or use the `aios` alias, to auto-load it via its `CLAUDE.md` + SessionStart hook). From other directories, read `~/code/aios-vault/CLAUDE.md` on demand ONLY when the task is personal or AIOS work — do not pull it into unrelated coding sessions.

## graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
