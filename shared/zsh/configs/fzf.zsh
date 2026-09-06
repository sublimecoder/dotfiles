#!/usr/bin/env zsh

if command -v fzf > /dev/null; then
  source <(fzf --zsh)
elif [[ -x ~/.fzf/bin/fzf ]]; then
  source <(~/.fzf/bin/fzf --zsh)
fi
