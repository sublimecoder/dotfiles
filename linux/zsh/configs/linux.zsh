# Linux-only shell config (Omarchy / Arch). Linked into ~/.zsh/configs/ by
# install.sh only when `uname -s` is not Darwin.

# Clipboard under Wayland/Hyprland. Named to match the macOS pbcopy/pbpaste pair
# so a script written against clip-copy works on either machine -- which is the
# whole reason for the shared spelling rather than aliasing pbcopy to wl-copy.
if command -v wl-copy >/dev/null; then
  alias clip-copy='wl-copy'
  alias clip-paste='wl-paste'
fi

# shasum lives here on Arch (perl-Digest-SHA), not in /usr/bin, and several AIOS
# hooks stamp files with it. Harmless when absent.
[ -d /usr/bin/core_perl ] && export PATH="$PATH:/usr/bin/core_perl"
