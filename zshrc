if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# load custom executable functions
for function in ~/.zsh/functions/*; do
  source $function
done

# extra files in ~/.zsh/configs/pre , ~/.zsh/configs , and ~/.zsh/configs/post
# these are loaded first, second, and third, respectively.
_load_settings() {
  _dir="$1"
  if [ -d "$_dir" ]; then
    if [ -d "$_dir/pre" ]; then
      for config in "$_dir"/pre/**/*~*.zwc(N-.); do
        . $config
      done
    fi

    for config in "$_dir"/**/*(N-.); do
      case "$config" in
        "$_dir"/(pre|post)/*|*.zwc)
          :
          ;;
        *)
          . $config
          ;;
      esac
    done

    if [ -d "$_dir/post" ]; then
      for config in "$_dir"/post/**/*~*.zwc(N-.); do
        . $config
      done
    fi
  fi
}
_load_settings "$HOME/.zsh/configs"

alias vim='MIX_ENV=test nvim'
alias vi='MIX_ENV=test nvim'
alias v='MIX_ENV=test nvim'

export PATH="/Users/jsmith/.emacs.d/bin:$PATH"

export PATH="$HOME/.bin:$PATH"

eval "$(direnv hook zsh)"

[ -d /opt/homebrew/opt/rabbitmq/sbin ] && export PATH="$PATH:/opt/homebrew/opt/rabbitmq/sbin"

export PATH="$PATH:$(go env GOPATH)/bin"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jsmith/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/jsmith/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jsmith/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jsmith/google-cloud-sdk/completion.zsh.inc'; fi
export PATH="$HOME/.local/bin:$PATH"

# aliases
[[ -f ~/.aliases ]] && source ~/.aliases

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bun completions
[ -s "/Users/jsmith/.bun/_bun" ] && source "/Users/jsmith/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Launch Claude Code in the Obsidian vault
alias vault='cd "/Users/jsmith/Library/Mobile Documents/iCloud~md~obsidian/Documents" && claude'
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
