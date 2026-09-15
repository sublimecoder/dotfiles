#!/usr/bin/env bash
# shellcheck disable=SC2016  # jq programs reference $vars inside single quotes on purpose
set -euo pipefail

# Restores the layer-neutral half of the Claude Code setup. The other half --
# anything naming an identity layer -- is owned by the private vault's
# aios-install.sh, which install.sh runs next.
#
# ~/.claude/settings.json is MERGED, never symlinked: Claude Code writes to it at
# runtime (/model, plugin toggles), and a symlink would commit every toggle to a
# public repo. settings.base.json wins on the keys it names; every other key
# (including the vault's) passes through, and nothing is ever deleted.
#
# DOTFILES_OFFLINE=1 skips everything that needs the network (test-install.sh).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
BASE="$HERE/settings.base.json"
OFFLINE="${DOTFILES_OFFLINE:-0}"

merge_settings() {
  local target="$CLAUDE_HOME/settings.json" tmp
  if ! command -v jq >/dev/null; then echo "MISSING jq -- skipped settings merge"; return 0; fi
  mkdir -p "$CLAUDE_HOME"
  [ -f "$target" ] || echo '{}' > "$target"
  tmp="$(mktemp)"
  if ! jq -s '.[0] * .[1]' "$target" "$BASE" > "$tmp"; then
    rm -f "$tmp"; echo "ERROR: $target is not valid JSON -- left untouched" >&2; return 1
  fi
  if jq -e --slurpfile cur "$target" '. == $cur[0]' "$tmp" >/dev/null; then
    rm -f "$tmp"; echo "already merged: $target"; return 0
  fi
  diff <(jq -S . "$target") <(jq -S . "$tmp") || true
  cp -p "$target" "$target.dotfiles-bak-$(date +%Y%m%dT%H%M%S)"
  mv "$tmp" "$target"
  echo "merged settings.base.json into $target"
}

install_plugins() {
  local name repo plugin known="$CLAUDE_HOME/plugins/known_marketplaces.json" installed="$CLAUDE_HOME/plugins/installed_plugins.json"
  if ! command -v claude >/dev/null; then echo "MISSING claude -- skipped plugins"; return 0; fi
  jq -r '.extraKnownMarketplaces | to_entries[] | "\(.key) \(.value.source.repo)"' "$BASE" |
    while read -r name repo; do
      if jq -e --arg n "$name" 'has($n)' "$known" >/dev/null 2>&1; then echo "marketplace ok: $name"
      else claude plugin marketplace add "$repo" </dev/null; fi
    done
  jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$BASE" |
    while read -r plugin; do
      if jq -e --arg p "$plugin" '.plugins | has($p)' "$installed" >/dev/null 2>&1; then echo "plugin ok: $plugin"
      else claude plugin install "$plugin" --scope user </dev/null; fi
    done
}

# Returns 0 only when it cloned, so a one-time setup step can hang off it.
clone_once() {
  [ -d "$2/.git" ] && return 1
  git clone --depth 1 "$1" "$2"
}

install_skills() {
  local d name src skill
  if ! command -v git >/dev/null; then echo "MISSING git -- skipped skill clones"; else
    if clone_once https://github.com/garrytan/gstack.git "$CLAUDE_HOME/skills/gstack"; then
      if command -v bun >/dev/null; then
        (cd "$CLAUDE_HOME/skills/gstack" && ./setup --host claude --no-prefix -q)
      else
        echo "MISSING bun -- gstack cloned but not set up; install bun, then: cd ~/.claude/skills/gstack && ./setup --host claude --no-prefix -q"
      fi
    fi
    clone_once https://github.com/emilkowalski/skills.git "$CLAUDE_HOME/vendor/emilkowalski-skills" || true
    for d in "$CLAUDE_HOME/vendor/emilkowalski-skills/skills"/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      [ -e "$CLAUDE_HOME/skills/$name" ] || ln -s "${d%/}" "$CLAUDE_HOME/skills/$name"
    done
  fi
  if ! command -v npx >/dev/null; then echo "MISSING npx -- skipped $(wc -l < "$HERE/skills.tsv" | tr -d ' ') skills in skills.tsv"; return 0; fi
  while IFS=$'\t' read -r src skill; do
    [ -n "$skill" ] || continue
    [ -e "$HOME/.agents/skills/$skill" ] && continue
    npx -y skills add "$src" -g -a claude-code -s "$skill" -y </dev/null
  done < "$HERE/skills.tsv"
}

wire_integrations() {
  local c
  # herdr and graphify each install their own Claude integration; the file they
  # write is theirs ("managed by herdr; reinstalling overwrites this file").
  if command -v herdr >/dev/null && [ ! -f "$CLAUDE_HOME/hooks/herdr-agent-state.sh" ]; then
    herdr integration install claude
  fi
  if command -v graphify >/dev/null && [ ! -e "$CLAUDE_HOME/skills/graphify" ]; then
    graphify install --platform claude
  fi
  # Placeholder report: plan Task 6 swaps this for rtk's own hook installer once confirmed.
  if command -v rtk >/dev/null && [ ! -f "$CLAUDE_HOME/hooks/rtk-rewrite.sh" ]; then
    echo "rtk is installed but its Claude hook is not -- see rtk's docs for the hook installer"
  fi
  for c in rtk graphify herdr bun npx; do
    command -v "$c" >/dev/null || echo "MISSING $c (optional; the hook or skill that needs it stays inert)"
  done
}

merge_settings
if [ "$OFFLINE" = 1 ]; then
  echo "DOTFILES_OFFLINE=1 -- skipped plugins, skills, integrations"
else
  install_plugins
  install_skills
  wire_integrations
fi
