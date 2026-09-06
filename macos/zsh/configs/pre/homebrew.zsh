# Homebrew, in `pre` because everything after it may want brew-installed tools
# on PATH. This ran at the top of zshrc before the OS split; the loader's `pre`
# stage is the same position expressed in the split layout.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
