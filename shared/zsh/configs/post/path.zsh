# ensure dotfiles bin directory is loaded first
PATH="$HOME/.bin:/usr/local/sbin:$PATH"

command -v mise >/dev/null && eval "$(mise activate zsh)"

# mkdir .git/safe in the root of repositories you trust
PATH=".git/safe/../../bin:$PATH"

export -U PATH
