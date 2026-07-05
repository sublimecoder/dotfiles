# Dotfiles consolidation design

## Goal

Replace the current two-repo, thoughtbot-fork-based dotfiles setup with a single,
fully self-owned repo. No more base/local split, no rcm dependency, no
thoughtbot lineage.

## Current state

- `~/dotfiles` — fork of `thoughtbot/dotfiles`. Remote `origin` =
  `sublimecoder/dotfiles` (public), remote `upstream` = `thoughtbot/dotfiles`.
  Carries thoughtbot's README, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
  `CODEOWNERS`, and two `.github/workflows/*` jobs that let a thoughtbot bot
  push template-sync commits into this repo (`dynamic-readme.yml`,
  `dynamic-security.yml` — these account for the generic "Updates"/"Update"
  commits in the log).
- `~/dotfiles-local` — separate repo, `origin` = `sublimecoder/dotfiles-local`
  (also public). Holds personal overrides (`aliases.local`, `gitconfig.local`,
  `vimrc.local`, `vimrc.bundles.local`, `zshrc.local`, `psqlrc.local`, a vendored
  zsh completion script) that rcm layers on top of the base repo via
  `DOTFILES_DIRS="$HOME/dotfiles-local $HOME/dotfiles"` in `rcrc`.
- Installed via `rcm` (`rcup`), which symlinks both repos' files into `$HOME`,
  giving local-dir files precedence over base-dir files for same-named
  targets.
- `~/dotfiles` has uncommitted WIP (bun setup, Android SDK paths, an Obsidian
  `vault` alias, Claude Code runtime gitignore entries) sitting directly in the
  base repo's `zshrc`/`gitignore`/`git_template/info/exclude` — including a
  duplicated `bun` block and a duplicated `**/.claude/settings.local.json`
  gitignore line.
- `~/.gitconfig-work.local` is a symlink into `dotfiles-local` whose target
  file no longer exists (dangling) — dead work-git-identity split.
- `~/.git_template.local/hooks/pre-commit` and (historically)
  `~/.git_signing_key.local` live outside both repos entirely, referenced by
  `git_template/hooks/*` via `local_hook="$HOME"/.git_template.local/hooks/...`.
  The signing-key file no longer exists (removed in a prior commit); this path
  is out of scope for this migration.

## Target state

One repo, `~/dotfiles`, GitHub `sublimecoder/dotfiles` (new, public), no
`upstream` remote, no rcm, no `.local`-suffix convention. A single flat file
per tool, installed by a small custom script.

## History plan

1. `dotfiles-local`'s full commit history (2+ years, already entirely
   first-party) becomes the new repo's git history — it's imported as-is.
2. On top of it, one commit adds the actual dotfiles content currently in
   `~/dotfiles` (merged with the `.local` counterparts per the file-by-file
   plan below), rewritten to drop all thoughtbot-derived files.
3. The thoughtbot fork's own commit history is **not** carried forward —
   it's mostly bot-generated template-sync noise plus commits that predate
   this being a personally-owned project.

## GitHub plan

- Create `sublimecoder/dotfiles` as a new (non-fork) public repo.
- Once the new repo is pushed and verified working end to end, archive
  `sublimecoder/dotfiles` (old fork) and `sublimecoder/dotfiles-local` on
  GitHub (read-only, kills the thoughtbot bot's write access for good).
- Do not delete the old repos — archive only, history stays visible.

## Install mechanism

- Drop `rcm`/`rcup` and the `rcrc` config entirely.
- Replace with a single install script (e.g. `install.sh`) that iterates the
  repo's dotfiles and symlinks each one to `~/.<name>` in `$HOME`, skipping
  non-dotfile files (`README.md`, the script itself). No external dependency.
- `git_template` continues to be wired via
  `git config --global init.templatedir ~/.git_template` (already the case
  today via `gitconfig`'s `[init] templatedir`).

## File-by-file merge plan

Each `X` (base) + `X.local` (local) pair collapses into a single flat `X` in
the new repo, and the `[[ -f ~/.X.local ]] && source ~/.X.local`-style glue
that sourced the local file is deleted along with it.

| File | Merge notes |
|---|---|
| `zshrc` | Merge both. Dedupe the doubled `bun` block (currently pasted twice in the uncommitted WIP diff). Keep all in-flight additions: bun, Android SDK paths, `vault` alias (Obsidian), Claude Code path exports. Drop the `~/.zshrc.local` source line. |
| `aliases` | Merge base unix/bundler/rails aliases with the personal git/tmux/elixir/go alias set from `aliases.local`. Drop the `~/.aliases.local` source line. |
| `vimrc` | Merge with `vimrc.local`. |
| `vimrc.bundles` | Merge plugin list with `vimrc.bundles.local` (jellybeans, vim-markdown, vimux, tmux-navigator, gist-vim, jsx/typescript plugins, styled-components). Drop the `~/.vimrc.bundles.local` source conditional. |
| `gitconfig` | Merge in the personal identity block (`name = Jared Smith`, `email = jared.smith88@me.com`) and the `heroku`/alias entries from `gitconfig.local`. Drop the `[include] path = ~/.gitconfig.local` line and the dangling `~/.git_signing_key.local` include (file no longer exists). Single identity — no work/personal split (per decision below). |
| `asdfrc` | Identical in both repos today — keep one copy. |
| `psqlrc` | Drop the `\i ~/.psqlrc.local` line — nothing left to override once merged. |
| `zsh/completion/_mix` | Keep as-is (vendored zsh-users completion script), goes alongside the existing `zsh/completion/*` files. |
| `tmp/build-errors.log` | Delete — accidental committed cruft. Add `tmp/` to the new repo's gitignore so it can't happen again. |
| `gitignore` | Merge, dedupe the doubled `**/.claude/settings.local.json` line. |
| `git_template/info/exclude` | Carry forward the uncommitted WIP additions (Claude Code runtime ignores, impeccable config ignores, `CLAUDE.local.md` pointer). |

### Decisions already made (not re-litigated during implementation)

- **Work git identity**: dropped. `~/.gitconfig-work.local` dangling symlink
  is deleted, no `includeIf` split — one identity everywhere.
- **Visibility**: new repo is public, same as both current repos. No
  portability/local-override abstraction is being (re-)added — "if someone
  wants to copy it they can" is fine as-is.

## Dropped entirely

`README.md`, `README-ES.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
`CODEOWNERS`, `.github/workflows/dynamic-readme.yml`,
`.github/workflows/dynamic-security.yml`, the `upstream` remote. The new repo
gets a short, original README describing what it is and the install script.

## Out of scope

- `~/.git_template.local/hooks/pre-commit` and anything else under
  `~/.git_template.local` — lives outside both repos today and stays that
  way; not part of this migration.
- Deep content-level audit of every alias/vim plugin for staleness (e.g. pinned
  tool versions) — flagged as a possible follow-up, not part of this pass.
- Hardcoded absolute paths using `/Users/jsmith/...` instead of `$HOME/...`
  (bun completion line, Obsidian vault alias, Fortify tool path in the old
  `zshrc.local`) — cosmetic, not fixed as part of this migration unless it
  blocks the merge.

## Verification plan

After migration, before archiving the old repos:

1. Fresh-shell smoke test: open a new terminal, confirm `zsh` loads without
   errors or duplicate exports (check `echo $PATH` for exactly one `bun`/
   `ASDF`/Android SDK entry each).
2. `git config --get user.email` resolves to `jared.smith88@me.com` from the
   merged `gitconfig` alone (no `.local` include).
3. `vim` starts, runs `:PlugStatus` (or equivalent) to confirm the merged
   plugin list installs cleanly.
4. `ls -la ~` shows every dotfiles-managed symlink pointing into the new
   single repo, and no leftover symlinks into `~/dotfiles-local` or the
   dangling `~/.gitconfig-work.local`.
5. `git -C ~/dotfiles remote -v` shows only `origin` pointing at the new
   `sublimecoder/dotfiles`, no `upstream`.
