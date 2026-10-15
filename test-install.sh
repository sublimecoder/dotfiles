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
setup() { HOME="$1" DOTFILES_OFFLINE=1 bash "$HERE/claude/setup.sh" 2>&1; }
BASE="$HERE/claude/settings.base.json"

echo "claude/setup.sh self-check"

# --- the base file itself ---------------------------------------------------
chk "base owns no vault keys" "false" "$(jq 'has("skillOverrides") or has("autoMode")' "$BASE")"
chk "base has no absolute home path" "0" "$(grep -cE '/Users/|/home/' "$BASE")"

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

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
