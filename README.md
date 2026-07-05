# dotfiles

Personal shell, git, vim, and tmux config. One flat repo, no local-override
layer — every file here is meant to be edited directly.

## Install

```bash
git clone git@github.com:sublimecoder/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` symlinks each file into `$HOME` (e.g. `zshrc` -> `~/.zshrc`,
`bin/*` -> `~/.bin/*`). Re-run it any time after adding a new file — it's
safe to run repeatedly, and it won't overwrite a real (non-symlink) file
that's already at the destination.

On a fresh machine, also point git at the commit template:

```bash
git config --global init.templatedir ~/.git_template
```

## Layout

- `zshrc`, `aliases`, `zshenv`, `zprofile` — shell
- `zsh/` — shell functions, completions, and config fragments loaded by `zshrc`
- `vimrc`, `vimrc.bundles` — vim, plugins via vim-plug
- `vim/` — filetype and plugin config
- `gitconfig`, `gitmessage`, `git_template/` — git config and commit template/hooks
- `tmux.conf` — tmux
- `bin/` — small personal scripts, put on `$PATH` via `install.sh`

If you want to copy any of this, go ahead — there's no portability layer
here, it's just what's on this machine.
