#!/usr/bin/env bash
# shellcheck disable=SC2010,SC2016  # ls|grep counts backups; the stub body is literal
# Self-check for claude/setup.sh (and, from Task 5, install.sh's chain).
# Hermetic: HOME is a scratch dir and DOTFILES_OFFLINE=1 skips every network step.
# The properties worth proving: owned keys land, unowned keys survive, nothing
# machine-absolute is written, and a second run is a byte-identical no-op.
set -u
# Isolate from the caller's shell: an exported AIOS_VAULT_REMOTE would make the
# H5 case below clone the private vault over the network instead of exercising
# the no-vault message.
unset AIOS_VAULT_REMOTE
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
chk() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   $1"; else FAIL=$((FAIL+1)); echo "  FAIL $1 (want [$2] got [$3])"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# A stub brew on PATH for every install.sh invocation in this file, not just
# the one under direct test: if the DOTFILES_OFFLINE gate around `brew bundle`
# ever regresses, this must catch it everywhere, not just in the case that
# happens to exercise it -- a real `brew bundle install` must never run here.
mkdir -p "$T/bin"; printf '#!/bin/sh\necho STUB-BREW\n' > "$T/bin/brew"; chmod +x "$T/bin/brew"
# Same reason for mise: `mise install` materializes the global tool list, and a
# real one here would download node/uv into the scratch HOME over the network.
printf '#!/bin/sh\necho STUB-MISE "$@"\n' > "$T/bin/mise"; chmod +x "$T/bin/mise"
# And nvim: `Lazy! restore` would clone every plugin over the network.
printf '#!/bin/sh\necho STUB-NVIM "$@"\n' > "$T/bin/nvim"; chmod +x "$T/bin/nvim"
setup() { HOME="$1" DOTFILES_OFFLINE=1 bash "$HERE/claude/setup.sh" 2>&1; }
BASE="$HERE/claude/settings.base.json"

echo "claude/setup.sh self-check"

# --- the base file itself ---------------------------------------------------
chk "base owns no vault keys" "false" "$(jq 'has("skillOverrides") or has("autoMode")' "$BASE")"
chk "base has no absolute home path" "0" "$(grep -cE '/Users/|/home/' "$BASE")"
# ~/.gitconfig is a symlink here, so `git config --global` writes this file and
# expands ~ on the way -- it has twice baked /home/jsmith in, which the Mac lacks.
chk "gitconfig has no absolute home path" "0" "$(grep -cE '/Users/|/home/' "$HERE/shared/gitconfig")"

# --- fresh machine: no settings.json at all -----------------------------------
H1="$T/fresh"; mkdir -p "$H1"
setup "$H1" >/dev/null
chk "fresh: settings created with the base model" "opus[1m]" "$(jq -r .model "$H1/.claude/settings.json")"
chk "fresh: ponytail enabled" "true" "$(jq -r '.enabledPlugins["ponytail@ponytail"]' "$H1/.claude/settings.json")"

# --- existing machine: foreign keys, a stale owned value ----------------------
H2="$T/existing"; mkdir -p "$H2/.claude"
cat > "$H2/.claude/settings.json" <<'EOF'
{"theme": "dark", "model": "sonnet", "skillOverrides": {"x": "off"}, "enabledPlugins": {"local@m": true}}
EOF
out=$(setup "$H2")
S="$H2/.claude/settings.json"
chk "stale owned key replaced"            "opus[1m]" "$(jq -r .model "$S")"
chk "foreign key kept"                    "dark"     "$(jq -r .theme "$S")"
chk "vault-owned key passed through"      "off"      "$(jq -r .skillOverrides.x "$S")"
chk "local plugin kept (deep merge)"      "true"     "$(jq -r '.enabledPlugins["local@m"]' "$S")"
chk "base plugin added (deep merge)"      "true"     "$(jq -r '.enabledPlugins["superpowers@superpowers-marketplace"]' "$S")"
chk "no absolute home path written"       "0"        "$(grep -cE '/Users/|/home/' "$S")"
chk "backup written"                      "1"        "$(ls "$H2/.claude" | grep -c 'settings.json.dotfiles-bak')"

# --- idempotence ----------------------------------------------------------------
snap="$(cat "$S")"
out=$(setup "$H2")
chk "second run byte-identical"           "$snap"    "$(cat "$S")"
chk "second run says so"                  "1"        "$(printf '%s' "$out" | grep -c 'already merged')"
chk "second run writes no second backup"  "1"        "$(ls "$H2/.claude" | grep -c 'settings.json.dotfiles-bak')"

# --- invalid JSON is left exactly as found ------------------------------------
H3="$T/broken"; mkdir -p "$H3/.claude"; printf '{"model": ' > "$H3/.claude/settings.json"
setup "$H3" >/dev/null; rc=$?
chk "invalid settings: non-zero exit"     "1"        "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"
chk "invalid settings: untouched"         '{"model": ' "$(cat "$H3/.claude/settings.json")"

# --- install.sh chain (Task 5) ------------------------------------------------
# A stub vault proves the handoff without touching the real one.
H4="$T/chain"; mkdir -p "$H4/code/aios-vault/AIOS/Systems"
printf '#!/bin/sh\necho "stub aios-install $*"\n' > "$H4/code/aios-vault/AIOS/Systems/aios-install.sh"
out=$(PATH="$T/bin:$PATH" HOME="$H4" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" 2>&1)
chk "chain: settings merged via setup.sh"   "opus[1m]" "$(jq -r .model "$H4/.claude/settings.json" 2>/dev/null)"
chk "chain: vault installer applied"        "1" "$(printf '%s' "$out" | grep -c 'stub aios-install --apply')"
chk "chain: statusline hook still linked"   "1" "$([ -L "$H4/.claude/hooks/statusline.sh" ] && echo 1 || echo 0)"
chk "chain: brew skipped offline"           "0" "$(printf '%s' "$out" | grep -c 'STUB-BREW')"
chk "chain: mise install skipped offline"   "0" "$(printf '%s' "$out" | grep -c 'STUB-MISE install')"
chk "chain: mise tool list linked"          "1" "$([ -L "$H4/.config/mise/config.toml" ] && echo 1 || echo 0)"
chk "chain: ssh agent env.d linked"         "1" "$([ -L "$H4/.config/environment.d/ssh-agent.conf" ] && echo 1 || echo 0)"
chk "chain: nvim init.lua linked"           "1" "$([ -L "$H4/.config/nvim/init.lua" ] && echo 1 || echo 0)"
# A link whose source left the repo is pruned; a broken link elsewhere, and one
# inside a .git dir, are not ours to touch.
ln -s "$HERE/shared/zsh/configs/gone.zsh" "$H4/.zsh/configs/gone.zsh"
ln -s "$T/nowhere" "$H4/.zsh/configs/foreign"
mkdir -p "$H4/.claude/repo/.git/hooks"; ln -s "$HERE/shared/git_template/hooks/gone" "$H4/.claude/repo/.git/hooks/gone"
PATH="$T/bin:$PATH" HOME="$H4" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" >/dev/null 2>&1
chk "prune: repo link with no source removed" "no"  "$([ -L "$H4/.zsh/configs/gone.zsh" ] && echo yes || echo no)"
chk "prune: foreign broken link kept"        "yes" "$([ -L "$H4/.zsh/configs/foreign" ] && echo yes || echo no)"
chk "prune: link inside .git kept"           "yes" "$([ -L "$H4/.claude/repo/.git/hooks/gone" ] && echo yes || echo no)"
chk "chain: nvim lockfile linked"           "1" "$([ -L "$H4/.config/nvim/lazy-lock.json" ] && echo 1 || echo 0)"
chk "chain: nvim restore skipped offline"   "0" "$(printf '%s' "$out" | grep -c 'STUB-NVIM')"
# shellrc in bash: EDITOR set, and `v` expands at use rather than being frozen
# empty at definition (VISUAL was once zsh-only, so bash got `alias v=''`).
chk "shellrc: EDITOR is nvim"               "nvim" "$(HOME="$H4" bash -c '. "$HOME/.shellrc" >/dev/null 2>&1; echo "$EDITOR"')"
# Omarchy runs bash, so the Wayland clipboard must come through ~/.shellrc, not ~/.zsh.
chk "shellrc: clip-copy defined in bash"    "function" "$(HOME="$H4" bash -c '. "$HOME/.shellrc" >/dev/null 2>&1; type -t clip-copy')"
chk "shellrc: v alias expands at use"       "alias v='\$VISUAL'" "$(HOME="$H4" bash -c '. "$HOME/.shellrc" >/dev/null 2>&1; alias v')"

# --- a ~/.config/nvim this repo does not own is moved aside whole -------------
# Mac: an init.vim beside the linked init.lua makes nvim refuse to start.
H7="$T/old-nvim"; mkdir -p "$H7/.config/nvim"; echo 'source ~/.vimrc' > "$H7/.config/nvim/init.vim"
PATH="$T/bin:$PATH" HOME="$H7" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" >/dev/null 2>&1
chk "mac: old init.vim gone from nvim dir"  "no" "$([ -e "$H7/.config/nvim/init.vim" ] && echo yes || echo no)"
chk "mac: old dir kept, init.vim inside"    "1" "$(ls "$H7"/.config/nvim.pre-dotfiles-*/init.vim 2>/dev/null | grep -c .)"
chk "mac: init.lua linked in its place"     "1" "$([ -L "$H7/.config/nvim/init.lua" ] && echo 1 || echo 0)"
# Fresh Omarchy: the LazyVim starter as real files, which link() would skip.
H8="$T/starter-nvim"; mkdir -p "$H8/.config/nvim/lua/config"
echo 'require("config.lazy")' > "$H8/.config/nvim/init.lua"; echo '-- starter' > "$H8/.config/nvim/lua/config/options.lua"
PATH="$T/bin:$PATH" HOME="$H8" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" >/dev/null 2>&1
chk "omarchy: starter options.lua replaced" "1" "$([ -L "$H8/.config/nvim/lua/config/options.lua" ] && echo 1 || echo 0)"
chk "omarchy: starter kept aside"           "1" "$(ls -d "$H8"/.config/nvim.pre-dotfiles-* 2>/dev/null | grep -c .)"
# Second run on an owned config moves nothing.
PATH="$T/bin:$PATH" HOME="$H8" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" >/dev/null 2>&1
chk "owned config: second run moves nothing" "1" "$(ls -d "$H8"/.config/nvim.pre-dotfiles-* 2>/dev/null | grep -c .)"

# --- macOS run (uname stubbed): same nvim/editor result, Mac files instead of Linux --
M="$T/mac"; mkdir -p "$M/bin" "$M/home"
printf '#!/bin/sh\n[ "$1" = -s ] && echo Darwin || /usr/bin/uname "$@"\n' > "$M/bin/uname"; chmod +x "$M/bin/uname"
PATH="$M/bin:$T/bin:$PATH" HOME="$M/home" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" >/dev/null 2>&1
chk "mac: nvim init.lua linked"             "1" "$([ -L "$M/home/.config/nvim/init.lua" ] && echo 1 || echo 0)"
chk "mac: macos.zsh linked"                 "1" "$([ -L "$M/home/.zsh/configs/macos.zsh" ] && echo 1 || echo 0)"
chk "mac: linux clip-copy not linked"       "no" "$([ -e "$M/home/.shell/functions/clip-copy" ] && echo yes || echo no)"
chk "mac: EDITOR is nvim"                   "nvim" "$(HOME="$M/home" bash -c '. "$HOME/.shellrc" >/dev/null 2>&1; echo "$EDITOR"')"

# --- git default-branch: origin/HEAD when set, main otherwise --------------------
G="$T/gitdb"; git init -q --template= -b master "$G"
chk "default-branch: no origin/HEAD is main" "main" "$(git -C "$G" -c include.path="$HERE/shared/gitconfig" default-branch)"
git -C "$G" commit -q --allow-empty --no-gpg-sign -m x
git -C "$G" update-ref refs/remotes/origin/master HEAD
git -C "$G" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
chk "default-branch: follows origin/HEAD"   "master" "$(git -C "$G" -c include.path="$HERE/shared/gitconfig" default-branch)"
# A remote-set origin/HEAD naming an option-like ref must not reach `git rebase -i`.
git -C "$G" update-ref refs/remotes/origin/--exec=touch HEAD
git -C "$G" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/--exec=touch
chk "default-branch: option-like name rejected" "main" "$(git -C "$G" -c include.path="$HERE/shared/gitconfig" default-branch)"

# --- herdr-run-below: reuse the pane below, split one off only when none ------
R="$T/herdr"; mkdir -p "$R/bin"
cat > "$R/bin/herdr" <<EOF
#!/bin/sh
echo "\$*" >> "$R/calls"
case "\$2" in
  neighbor) echo '{"result":{"neighbor":{"pane_id":"'"\$(cat "$R/below")"'"}}}' ;;
  split)    echo '{"result":{"pane":{"pane_id":"new"}}}' ;;
esac
EOF
chmod +x "$R/bin/herdr"
echo p1 > "$R/below"; : > "$R/calls"
PATH="$R/bin:$PATH" HERDR_PANE_ID=p1 bash "$HERE/shared/bin/herdr-run-below" "mix test"
chk "herdr: no pane below, splits one"      "1" "$(grep -c '^pane split p1 --direction down' "$R/calls")"
chk "herdr: runs in the new pane"           "1" "$(grep -c '^pane run new cd .* && mix test$' "$R/calls")"
echo p2 > "$R/below"; : > "$R/calls"
PATH="$R/bin:$PATH" HERDR_PANE_ID=p1 bash "$HERE/shared/bin/herdr-run-below" "mix test"
chk "herdr: pane below, no split"           "0" "$(grep -c '^pane split' "$R/calls")"
chk "herdr: runs in the pane below"         "1" "$(grep -c '^pane run p2 ' "$R/calls")"

H5="$T/novault"; mkdir -p "$H5"
out=$(PATH="$T/bin:$PATH" HOME="$H5" DOTFILES_OFFLINE=1 bash "$HERE/install.sh" 2>&1)
chk "no vault, no remote: says how"         "1" "$(printf '%s' "$out" | grep -c 'AIOS_VAULT_REMOTE')"

# --- offline must skip the clone even when a remote is given (D4) ------------
# A bogus remote proves it: if install.sh tried to clone it, that clone would
# fail loudly (or, worse, actually reach the network) instead of the vault
# simply staying absent.
H6="$T/offline-with-remote"; mkdir -p "$H6"
out=$(PATH="$T/bin:$PATH" HOME="$H6" DOTFILES_OFFLINE=1 AIOS_VAULT_REMOTE="https://example.invalid/nope.git" bash "$HERE/install.sh" 2>&1)
chk "offline: no clone attempted"           "0" "$(printf '%s' "$out" | grep -c 'Cloning into')"
chk "offline: no vault dir created"         "no" "$([ -d "$H6/code/aios-vault" ] && echo yes || echo no)"
chk "offline: no-vault message still prints" "1" "$(printf '%s' "$out" | grep -c 'AIOS_VAULT_REMOTE')"

# --- omarchy-provision --check: reports exactly what is absent, changes nothing --
# Stubs stand in for pacman/systemctl/omarchy so this runs on any machine. The
# fixture has one present and one absent item per kind; the check must name every
# absent one, none of the present ones, and the stub omarchy must never be called
# to change anything.
P="$T/provision"; mkdir -p "$P/bin" "$P/m/hosts" "$P/home/.config/omarchy/plugins/have.plugin" \
  "$P/home/.local/share/applications" "$P/home/.config/herdr"
printf '#!/bin/sh\n[ "$1" = -Qq ] && case "$2" in havepkg|haveaur) exit 0;; esac; exit 1\n' > "$P/bin/pacman"
printf '#!/bin/sh\ncase "$*" in *have.unit*) exit 0;; esac; exit 1\n' > "$P/bin/systemctl"
printf '#!/bin/sh\necho "$*" >> "%s/omarchy-calls"\n' "$P" > "$P/bin/omarchy"
chmod +x "$P/bin/"*
printf '{"bar":{"layout":{"right":[{"id":"omarchy.tray"},{"id":"have.widget"}]}}}\n' > "$P/home/.config/omarchy/shell.json"
touch "$P/home/.local/share/applications/Have App.desktop"
printf 'onboarding = false\n' > "$P/home/.config/herdr/config.toml"
cat > "$P/m/common.manifest" <<'EOF'
pkg havepkg
pkg needpkg
aur haveaur
aur needaur
omarchy pkg:havepkg install have
omarchy pkg:needpkg install need
plugin have.plugin https://example.invalid/have.git
plugin need.plugin https://example.invalid/need.git
bar have.widget
bar need.widget
webapp Have App|https://have.invalid|have
webapp Need App|https://need.invalid|need
unit system have.unit
unit system need.unit
setting herdr/config.toml onboarding false
setting herdr/config.toml show_agent_labels_on_pane_borders false
EOF
out=$(PATH="$P/bin:$PATH" HOME="$P/home" OMARCHY_PROVISION_MANIFESTS="$P/m" \
  bash "$HERE/linux/bin/omarchy-provision" --check --host nohost 2>&1); rc=$?
chk "provision check: exit 1 when items are missing" "1" "$rc"
chk "provision check: counts exactly the 8 absent"   "1" "$(printf '%s' "$out" | grep -c 'nohost: 8 missing')"
chk "provision check: names no present item"         "0" "$(printf '%s' "$out" | grep -cE 'missing  (pkg havepkg|aur haveaur|omarchy install have$|plugin have\.plugin|bar have\.widget|webapp Have App|system unit have\.unit|setting herdr/config\.toml: onboarding)')"
chk "provision check: bar keeps manifest order"      "1" "$(printf '%s' "$out" | grep -c 'bar need.widget (after have.widget)')"
chk "provision check: changed nothing"               "no" "$([ -f "$P/omarchy-calls" ] && echo yes || echo no)"

# --- omarchy-provision apply: a command that reads stdin must not eat the manifest --
# Omarchy installers prompt (gum confirm, yay menus). If the loop's stdin is the
# manifest, the first prompting command swallows every later line and the run
# silently stops early. This stub drains stdin like such a prompt would.
A="$T/apply"; mkdir -p "$A/bin" "$A/m" "$A/home/.config/omarchy" "$A/home/.local/share/applications"
printf '#!/bin/sh
exit 1
' > "$A/bin/pacman"
printf '#!/bin/sh
cat >/dev/null
echo "$*" >> "%s/calls"
' "$A" > "$A/bin/omarchy"
chmod +x "$A/bin/"*
printf '{"bar":{"layout":{"right":[]}}}\n' > "$A/home/.config/omarchy/shell.json"
printf 'omarchy pkg:x install one\nomarchy pkg:y install two\nwebapp Late|https://late.invalid|late\n' > "$A/m/common.manifest"
PATH="$A/bin:$PATH" HOME="$A/home" OMARCHY_PROVISION_MANIFESTS="$A/m" \
  bash "$HERE/linux/bin/omarchy-provision" --host nohost </dev/null >/dev/null 2>&1; rc=$?
chk "provision apply: every line runs past a prompting command" "3" "$(wc -l < "$A/calls" 2>/dev/null | tr -d ' ')"
chk "provision apply: exits non-zero when items stay missing"  "1" "$rc"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
