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

# Directory trees, mirrored file-by-file under ~/.<dir>/...
# Both shared/ and the OS dir feed the SAME destinations, which is what lets
# macos/zsh/configs/macos.zsh sit beside the shared configs at runtime.
link_tree() {
  local dir="$1" sub rel file
  for sub in bin zsh vim git_template claude; do
    [ -d "$dir/$sub" ] || continue
    while IFS= read -r -d '' file; do
      rel="${file#"$dir/$sub"/}"
      link "$DOTFILES_DIR/$file" "$HOME/.$sub/$rel"
    done < <(find "$dir/$sub" -type f -not -name '.DS_Store' -print0)
  done
}

link_top  "shared"
link_tree "shared"
link_top  "$OS_DIR"
link_tree "$OS_DIR"

if [ "$OS_DIR" = "macos" ] && command -v brew >/dev/null; then
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

echo
echo "Done. If this is a fresh machine, also run:"
echo "  git config --global init.templatedir ~/.git_template"
if [ "$OS_DIR" = "linux" ]; then
  echo "  and point the terminal at zsh -- see docs/shell-decision.md"
fi
