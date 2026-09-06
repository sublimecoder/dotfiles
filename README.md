# dotfiles

Personal shell and git config for two machines — a Mac and an Omarchy/Arch box —
from one repo and one branch.

`shared/` is linked everywhere; `macos/` or `linux/` is linked according to
`uname`. The split is done by *which files get linked*, not by a runtime OS test
inside the configs — so a per-OS setting is a new file in an OS directory, never
an edit to `zshrc`.

## Install

```bash
git clone git@github.com:sublimecoder/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` symlinks each file into `$HOME` (e.g. `shared/zshrc` ->
`~/.zshrc`, `shared/bin/*` -> `~/.bin/*`). Re-run it any time after adding a new
file — it's safe to run repeatedly, and it won't overwrite a real (non-symlink)
file that's already at the destination.

On macOS it also runs `brew bundle` against `macos/Brewfile`. On Linux it
**reports** anything missing from `linux/packages.txt` and installs nothing.

On a fresh machine, also point git at the commit template:

```bash
git config --global init.templatedir ~/.git_template
```

## Layout

- `shared/zshrc`, `shared/aliases`, `shared/zshenv` — shell
- `shared/zsh/` — functions, completions, and config fragments loaded by `zshrc`
- `shared/vimrc`, `shared/vim/` — vim (being retired; see the port plan)
- `shared/gitconfig`, `shared/gitmessage`, `shared/git_template/` — git
- `shared/bin/` — small personal scripts, on `$PATH` via `install.sh`
- `macos/` — Brewfile, zprofile, and the Homebrew / gcloud / Android / iCloud
  bits that exist only there
- `linux/` — `packages.txt` and the Wayland clipboard aliases

`macos/zsh/configs/` and `linux/zsh/configs/` link into the *same*
`~/.zsh/configs/` as the shared ones, so both halves load through one loader.

## Shell

Login shell is **bash** (Omarchy's default, and its tooling assumes it); the
terminal launches **zsh**, which is where `zsh/functions/g` and everything in
`zsh/configs/` lives. Set the terminal's shell, not `chsh`. Full reasoning,
the per-terminal config lines, and the install-configs-first ordering:
[`docs/shell-decision.md`](docs/shell-decision.md).

If you want to copy any of this, go ahead.
