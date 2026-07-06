#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

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

# Top-level dotfiles -> ~/.<name>
for f in *; do
  case "$f" in
    README.md|install.sh|Brewfile|.gitignore|.git|.DS_Store) continue ;;
  esac
  [ -d "$f" ] && continue
  link "$DOTFILES_DIR/$f" "$HOME/.$f"
done

# Directory trees, mirrored file-by-file under ~/.<dir>/...
for dir in bin zsh vim git_template; do
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$dir"/}"
    link "$DOTFILES_DIR/$file" "$HOME/.$dir/$rel"
  done < <(find "$dir" -type f -not -name '.DS_Store' -print0)
done

if command -v brew >/dev/null; then
  brew bundle install --file="$DOTFILES_DIR/Brewfile"
fi

echo
echo "Done. If this is a fresh machine, also run:"
echo "  git config --global init.templatedir ~/.git_template"
