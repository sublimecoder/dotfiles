# dotfiles conventions

Personal, single-owner dotfiles repo — flat and direct on purpose, no rcm-style
base+local override layers, no portability scaffolding. See git log for the
2026-07-05 consolidation that merged this repo with the old dotfiles-local.

## install.sh

`install.sh` symlinks everything into `$HOME`, no external tool (no rcm, no
GNU Stow):

- Top-level files symlink to `~/.<name>` (e.g. `zshrc` -> `~/.zshrc`), except
  the exclusion list in the `case` statement (`README.md`, `install.sh`,
  `Brewfile`, `.gitignore`, `.git`, `.DS_Store`). Adding a new top-level file
  that should NOT be symlinked into `$HOME` means adding it to that list.
- `bin/`, `zsh/`, `vim/`, `git_template/` are mirrored file-by-file under
  `~/.bin/`, `~/.zsh/`, etc. — every file inside, recursively.
- Re-run `install.sh` any time a file is added/removed; it's idempotent.
- Also runs `brew bundle install --file=Brewfile` to install/update packages.

## Package management

`mise` is the runtime version manager (not asdf — swapped 2026-07-05, see git
log). `Brewfile` tracks installed Homebrew formulae/casks/taps; regenerate
with `brew bundle dump --file=Brewfile --force` after installing something
new, and keep pins (`formula@version`) only for tools that actually need a
specific version — default to the unversioned/latest formula otherwise.

## Tooling philosophy

Single owner, single machine relationship — optimize for the simplest flat
setup, not portability or shareability. Don't add config layers, override
precedence, or "in case someone else uses this" abstractions.
