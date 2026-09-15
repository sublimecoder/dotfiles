@~/.claude/RTK.md

## Effort table — task type → model (machine-wide)
Canonical source is version-controlled in the vault and imported here, so it loads into **every** repo/session while its history lives in the vault's git. Pure model routing — no private content. Edit tiers in that file only.

@~/code/aios-vault/AIOS/Systems/effort-table.md

## Reasoning doctrine (machine-wide)
Standing cognitive procedures (intent-reading, fact re-derivation, certainty marking, self-attack, final gate) distilled from Fable 5 before its deprecation. Canonical in the vault, no private content, imported everywhere like the effort table. Edit rules in that file only.

@~/code/aios-vault/AIOS/Systems/reasoning-doctrine.md

## AIOS brain vault
The AIOS brain vault lives at `~/code/aios-vault` (run `claude` from there, or use the `aios` alias, to auto-load it via its `CLAUDE.md` + SessionStart hook). From other directories, read `~/code/aios-vault/CLAUDE.md` on demand ONLY when the task is personal or AIOS work — do not pull it into unrelated coding sessions.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

## Ponytail amendment (machine-wide)
Personal dead-code-asymmetry rule extending the ponytail plugin. Canonical in the vault (survives plugin upgrades), no private content, imported everywhere like [[effort-table]] and [[reasoning-doctrine]]. Edit the rule in that file only.

@~/code/aios-vault/AIOS/Systems/ponytail-amendment.md

## Plan-recon amendment (machine-wide)
Personal extension to the superpowers `writing-plans` skill: recon order is graph → grep → read → write, a brief cites only what it has opened, and cross-task seams get named. Canonical in the vault (survives plugin upgrades), no private content, imported everywhere like [[ponytail-amendment]]. Edit the rule in that file only.

@~/code/aios-vault/AIOS/Systems/plan-recon-amendment.md
