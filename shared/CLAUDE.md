# dotfiles conventions

Personal, single-owner dotfiles for **two machines**: a Mac and an Omarchy/Arch
box. One repo, one branch, no rcm and no GNU Stow.

**This repo was flat until 2026-09-05**, and its own docs said so — "optimize for
the simplest flat setup, not portability". That held while there was one machine.
It stopped holding the moment there were two: the flat `zshrc` carried 8 absolute
`/Users/jsmith` paths that did not resolve on Linux at all, and `brew`-vs-`pacman`
and `pbcopy`-vs-`wl-copy` are real forks rather than preferences. See git log for
the 2026-07-05 consolidation and the 2026-09-05 Omarchy port.

## Layout

```
shared/   linked on every machine
macos/    linked only when `uname -s` = Darwin
linux/    linked otherwise
```

**The split is done by which files get linked, not by branching at runtime.**
There is deliberately no `if [ "$(uname)" = Darwin ]` inside any config. If you
find yourself adding one, the file belongs in an OS directory instead.

The one mechanism that makes this cheap: `shared/zshrc` already sources
everything in `~/.zsh/configs/`, and BOTH `shared/zsh/configs/` and
`<os>/zsh/configs/` link into that same directory. So a new per-OS config is a
new file — never an edit to `zshrc`.

Ordering inside `~/.zsh/configs/` is `pre/` → top level → `post/`. Homebrew's
`shellenv` lives in `macos/zsh/configs/pre/` because everything after it expects
brew-installed tools on `PATH`.

## install.sh

Symlinks into `$HOME`, no external tool:

- Top-level files in `shared/` and the active OS dir → `~/.<name>`, except the
  exclusion list in the `case` (`README.md`, `CLAUDE.md`, `Brewfile`,
  `packages.txt`). A new top-level file that should NOT reach `$HOME` goes there.
- `bin/`, `zsh/`, `vim/`, `git_template/`, `claude/` are mirrored file-by-file
  under `~/.bin/`, `~/.zsh/`, etc.
- Never overwrites a real (non-symlink) file; it says `skip` and moves on.
- Idempotent — re-run it after adding or removing anything.
- macOS: runs `brew bundle install --file=macos/Brewfile`.
- Linux: **reports** missing packages from `linux/packages.txt` and installs
  nothing. An installer must not touch system packages unasked.

## Package management

`mise` is the runtime version manager on both machines (not asdf — swapped
2026-07-05). `macos/Brewfile` tracks Homebrew formulae; regenerate with
`brew bundle dump --file=macos/Brewfile --force`. `linux/packages.txt` is the
Arch equivalent and is hand-maintained.

## Shell

Login shell is bash on both; the terminal launches zsh. Reasoning and the
per-terminal config lines: `docs/shell-decision.md`. Do not `chsh`.

## Tooling philosophy

Single owner, two machines. Keep the shared half genuinely shared — a config
that needs a runtime OS test is a config that belongs in `macos/` or `linux/`.
Still no override precedence and no "in case someone else uses this"
abstraction: the OS split exists because two machines exist, and for no other
reason.
