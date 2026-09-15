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

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
