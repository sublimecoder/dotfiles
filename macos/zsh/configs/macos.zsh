# macOS-only shell config. Linked into ~/.zsh/configs/ by install.sh only when
# `uname -s` is Darwin, so nothing here needs a runtime OS test.
#
# Every path below was an absolute /Users/jsmith string in the old flat zshrc.
# They are $HOME-relative now, which is what lets one branch serve two machines.

# Doom Emacs
[ -d "$HOME/.emacs.d/bin" ] && export PATH="$HOME/.emacs.d/bin:$PATH"

# kimi-code
[ -d "$HOME/.kimi-code/bin" ] && export PATH="$HOME/.kimi-code/bin:$PATH"

[ -d /opt/homebrew/opt/rabbitmq/sbin ] && export PATH="$PATH:/opt/homebrew/opt/rabbitmq/sbin"

# Google Cloud SDK — path first, then completion.
[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/google-cloud-sdk/completion.zsh.inc"

# Android Studio toolchain. JAVA_HOME points inside the .app bundle, which is
# why this cannot be shared — there is no equivalent path on Linux.
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# The Obsidian vault lives in iCloud Drive, which only exists on macOS.
alias vault='cd "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents" && claude'

# Clipboard. Named the same as the Linux pair so anything scripted against them
# works on both machines.
alias clip-copy='pbcopy'
alias clip-paste='pbpaste'
