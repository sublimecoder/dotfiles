#!/usr/bin/env bash
# shellcheck disable=SC2010,SC2016  # ls|grep counts backups; the stub body is literal
# Self-check for claude/setup.sh (and, from Task 5, install.sh's chain).
# Hermetic: HOME is a scratch dir and DOTFILES_OFFLINE=1 skips every network step.
# The properties worth proving: owned keys land, unowned keys survive, nothing
# machine-absolute is written, and a second run is a byte-identical no-op.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
chk() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  ok   $1"; else FAIL=$((FAIL+1)); echo "  FAIL $1 (want [$2] got [$3])"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
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

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
