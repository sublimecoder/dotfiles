#!/usr/bin/env bash
set -euo pipefail

# Links shared/ always, plus exactly ONE of macos/ or linux/ chosen by uname.
#
# This replaced a flat repo whose README claimed "no local-override layer".
# That claim was true and it cost real breakage: brew-vs-pacman and
# pbcopy-vs-wl-copy are genuine forks, not preferences, and the flat zshrc
# carried 8 absolute /Users/jsmith paths that did not resolve on the second
# machine at all.
#
# The split is done by WHICH FILES GET LINKED, not by `if [ "$(uname)" = Darwin ]`
# inside the configs. OS-specific shell fragments land in ~/.zsh/configs/, where
# the loader in shared/zshrc already sources everything -- so adding a per-OS
# config needs no change to zshrc and no new mechanism.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

case "$(uname -s)" in
  Darwin) OS_DIR="macos" ;;
  *)      OS_DIR="linux" ;;
esac
echo "Linking shared/ and $OS_DIR/ ..."

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip (real file exists): $dest"
    return
  fi
  ln -nsf "$src" "$dest"
  echo "linked: $dest -> $src"
}

# Top-level files in a source dir -> ~/.<name>
link_top() {
  local dir="$1" f
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    [ -d "$f" ] && continue
    case "$(basename "$f")" in
      Brewfile|packages.txt|README.md|CLAUDE.md) continue ;;   # repo docs, not config
    esac
    link "$DOTFILES_DIR/$f" "$HOME/.$(basename "$f")"
  done
}

# Directory trees, mirrored file-by-file under ~/.<dir>/... (prune reads it too)
LINK_SUBS="bin shell zsh vim git_template claude config jcode"

# Both shared/ and the OS dir feed the SAME destinations, which is what lets
# macos/zsh/configs/macos.zsh sit beside the shared configs at runtime.
link_tree() {
  local dir="$1" sub rel file
  # jcode: only the prompt files (prompt-overlay.md, swarm-prompt.md). jcode
  # ignores ~/.claude/CLAUDE.md and @import, so these carry the AIOS effort table
  # and brain-loading rule into jcode. ~/.jcode/config.toml is NOT here: it is
  # owned by the vault's aios-install.sh, which merges hooks into it.
  for sub in $LINK_SUBS; do
    [ -d "$dir/$sub" ] || continue
    while IFS= read -r -d '' file; do
      rel="${file#"$dir/$sub"/}"
      link "$DOTFILES_DIR/$file" "$HOME/.$sub/$rel"
    done < <(find "$dir/$sub" -type f -not -name '.DS_Store' -print0)
  done
}

# ~/.claude/CLAUDE.md predates this repo as a REAL per-machine file, so link()
# would skip it forever -- and that copy imported the AIOS vault through absolute
# /Users/jsmith paths that resolve on no Linux machine, dropping the imports
# silently. Move a real one aside ONCE (kept, timestamped, never deleted) so the
# shared copy, which imports through ~/, links in its place.
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f shared/claude/CLAUDE.md ] && [ -e "$GLOBAL_CLAUDE_MD" ] && [ ! -L "$GLOBAL_CLAUDE_MD" ]; then
  aside="$GLOBAL_CLAUDE_MD.pre-dotfiles-$(date +%Y%m%dT%H%M%S)"
  mv "$GLOBAL_CLAUDE_MD" "$aside"
  echo "moved real $GLOBAL_CLAUDE_MD aside -> $aside (diff it for machine-local lines worth keeping)"
fi

# Same move-aside, for a ~/.config/nvim this repo does not own: the Mac's old
# init.vim (it sourced ~/.vimrc; beside init.lua nvim refuses to start with
# "Conflicting configs"), or the LazyVim starter a fresh Omarchy install copies
# in as REAL files, which link() would skip one by one. Ours is recognisable by
# init.lua being a symlink. The whole directory moves (or, if it is itself a
# symlink, only the link), so nothing is half-merged.
NVIM_DIR="$HOME/.config/nvim"
if [ -f shared/config/nvim/init.lua ] && { [ -e "$NVIM_DIR" ] || [ -L "$NVIM_DIR" ]; } \
   && [ ! -L "$NVIM_DIR/init.lua" ]; then
  aside="$NVIM_DIR.pre-dotfiles-$(date +%Y%m%dT%H%M%S)"
  mv "$NVIM_DIR" "$aside"
  echo "moved $NVIM_DIR aside -> $aside (not this repo's config)"
fi

link_top  "shared"
link_tree "shared"
link_top  "$OS_DIR"
link_tree "$OS_DIR"

# link() only adds, so a file renamed or deleted here left its link behind
# (~/.zsh/configs/editor.zsh outlived its source for weeks). Remove only BROKEN
# links that point INTO this repo; skip .git dirs, whose hooks git copied from
# the template and which belong to that repo.
prune() {
  local l
  while IFS= read -r -d '' l; do
    case "$(readlink "$l")" in
      "$DOTFILES_DIR"/*) rm "$l"; echo "pruned (source gone): $l" ;;
    esac
  done < <(find "$@" -name .git -prune -o -xtype l -print0 2>/dev/null)
}
prune "$HOME" -maxdepth 1
for sub in $LINK_SUBS; do
  [ -d "$HOME/.$sub" ] && prune "$HOME/.$sub"
done

if [ "$OS_DIR" = "macos" ] && [ "${DOTFILES_OFFLINE:-0}" != 1 ] && command -v brew >/dev/null; then
  brew bundle install --file="$DOTFILES_DIR/macos/Brewfile"
fi

# REPORT ONLY. An installer must not install system packages unasked -- the same
# stance the AIOS hooks take about starting a background agent.
if [ "$OS_DIR" = "linux" ] && [ -f linux/packages.txt ]; then
  missing=()
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    case "$pkg" in \#*) continue ;; esac
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done < linux/packages.txt
  if [ ${#missing[@]} -gt 0 ]; then
    echo
    echo "Missing packages (${#missing[@]}). Install with:"
    echo "  sudo pacman -S --needed ${missing[*]}"
  fi
fi

# REPORT ONLY, for the same reason as the packages block above: every step in
# setup-printers.sh needs root -- systemctl enable, lpadmin, and a backend
# dropped into /usr/lib/cups/backend -- while this installer runs unprivileged
# and touches no system state. Naming the script IS the integration.
if [ "$OS_DIR" = "linux" ] && [ -x linux/bin/setup-printers.sh ]; then
  queues="$(lpstat -v 2>/dev/null || true)"
  if [ -z "$queues" ]; then
    echo
    echo "No printers configured. To wire the Canon PIXMA (network, driverless)"
    echo "and the 4x6 thermal label printer (USB):"
    echo "  sudo $DOTFILES_DIR/linux/bin/setup-printers.sh"
  fi
fi

# REPORT ONLY, same stance again: the Omarchy layer (packages, installers, shell
# plugins, bar, web apps, services) is applied by omarchy-provision, which calls
# sudo. This only counts what it would do. Restic is `sudo restic-setup`.
if [ "$OS_DIR" = "linux" ] && [ "${DOTFILES_OFFLINE:-0}" != 1 ] && command -v omarchy >/dev/null; then
  if ! out="$("$DOTFILES_DIR/linux/bin/omarchy-provision" --check 2>&1)"; then
    echo
    printf '%s\n' "$out" | tail -1
    echo "  see the list: $DOTFILES_DIR/linux/bin/omarchy-provision --check"
  fi
fi

# ~/.bashrc is a REAL file on Omarchy carrying machine-local content (cargo,
# gcloud), so link() correctly refuses to replace it. Append one source line
# instead -- idempotent, and reversible by deleting the two lines.
BASHRC="$HOME/.bashrc"
MARK="# dotfiles: shell-neutral core (g, aliases, PATH) -- see ~/dotfiles"
if [ -f "$BASHRC" ] && ! grep -qF "$MARK" "$BASHRC"; then
  printf '\n%s\n[ -f "$HOME/.shellrc" ] && . "$HOME/.shellrc"\n' "$MARK" >> "$BASHRC"
  echo "appended shellrc source line to $BASHRC"
elif [ -f "$BASHRC" ]; then
  echo "already wired: $BASHRC"
fi

# shared/shellrc already prefers $XDG_RUNTIME_DIR/gcr/ssh over the plain
# ssh-agent socket, because gcr-ssh-agent keeps the passphrase in the login
# keyring instead of forgetting it every boot. Arch ships the unit but enables
# neither, so on a fresh machine that preferred socket never exists and the
# shellrc branch silently falls through -- leaving signed commits dying on
# ssh_askpass with the key sitting unlocked in a keyring nothing can reach.
# Enabling the socket is the whole fix; the key is added on first use by
# AddKeysToAgent in ~/.ssh/config.
if [ "$OS_DIR" = "linux" ] && [ "${DOTFILES_OFFLINE:-0}" != 1 ] \
   && [ -f /usr/lib/systemd/user/gcr-ssh-agent.socket ]; then
  systemctl --user enable --now gcr-ssh-agent.socket 2>/dev/null \
    || echo "could not enable gcr-ssh-agent.socket -- signed commits will need a manual agent"
fi

# Materialize the global mise tool list that shared/config/mise/config.toml was
# just linked into place. Not the same category as the pacman report above: mise
# installs into ~/.local/share/mise, needs no sudo, and claude/setup.sh depends
# on it one step later (uv -> graphify). Without this a fresh machine links a
# tool list it never acts on.
if [ "${DOTFILES_OFFLINE:-0}" != 1 ] && command -v mise >/dev/null; then
  mise install || echo "mise install failed -- tools stay absent; re-run: mise install"
fi

# Plugins at the versions pinned in shared/config/nvim/lazy-lock.json, so a fresh
# machine opens nvim ready instead of installing on first launch. User-local
# (~/.local/share/nvim), no sudo -- same category as mise above.
if [ "${DOTFILES_OFFLINE:-0}" != 1 ] && command -v nvim >/dev/null; then
  nvim --headless "+Lazy! restore" +qa \
    || echo "nvim plugin restore failed -- re-run: nvim --headless '+Lazy! restore' +qa"
fi

# Claude Code: the public half (settings merge, plugins, skills). See
# claude/setup.sh for why settings.json is merged rather than linked.
bash "$DOTFILES_DIR/claude/setup.sh"

# The private half lives in the AIOS vault. This public repo never names that
# repo's remote: pass it once on a fresh machine as AIOS_VAULT_REMOTE.
VAULT="$HOME/code/aios-vault"
if [ ! -d "$VAULT/.git" ] && [ ! -f "$VAULT/AIOS/Systems/aios-install.sh" ] && [ -n "${AIOS_VAULT_REMOTE:-}" ] \
   && [ "${DOTFILES_OFFLINE:-0}" != 1 ]; then
  git clone "$AIOS_VAULT_REMOTE" "$VAULT"
fi
if [ -f "$VAULT/AIOS/Systems/aios-install.sh" ]; then
  sh "$VAULT/AIOS/Systems/aios-install.sh" --apply
else
  echo "No vault at $VAULT -- re-run with AIOS_VAULT_REMOTE=<vault git url> to clone and wire it."
fi

echo
# NOT "also run: git config --global init.templatedir ~/.git_template".
# shared/gitconfig already sets it, and ~/.gitconfig is a SYMLINK into this
# repo -- so that command rewrites the tracked file, and git expands the ~ on
# write. It replaced the portable `~/.git_template` with an absolute
# /home/jsmith path, which resolves on the Mac not at all. Redundant and
# corrupting: the advice made the machine it ran on the only one it fit.
echo "Done."
if [ "$OS_DIR" = "linux" ]; then
  echo "Shell here is Omarchy's default bash; ~/.shellrc carries the portable core -- see docs/shell-decision.md"
fi
