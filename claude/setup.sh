#!/usr/bin/env bash
# shellcheck disable=SC2016  # jq programs reference $vars inside single quotes on purpose
set -euo pipefail

# Restores the public half of the Claude Code setup. The private half is owned
# by a separate installer, which install.sh runs next.
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

# A fresh machine runs install.sh before any shell has sourced ~/.shellrc, so
# neither uv's bin dir nor mise's shims are on PATH yet -- and wire_integrations
# installs through both. Prepend them for this script only; shared/shellrc makes
# it permanent for interactive shells.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# Runs LAST in the main flow below (after install_plugins, install_skills and
# wire_integrations) so settings.base.json's hook arrays win over anything an
# integration installer wrote to settings.json during this same run.
#
# Claude Code replaces a hook event array (PreToolUse, PostToolUse,
# SessionStart, ...) WHOLESALE, never merges within it -- so any hook another
# tool adds to one of those events is silently dropped the next time this
# script runs, unless it also lives in settings.base.json. herdr, rtk and
# gstack each write their own hook; if a future integration's hook isn't
# showing up after a re-run, this is why -- add it to settings.base.json.
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
      else claude plugin marketplace add "$repo" </dev/null || echo "FAILED marketplace $name"; fi
    done
  jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' "$BASE" |
    while read -r plugin; do
      if jq -e --arg p "$plugin" '.plugins | has($p)' "$installed" >/dev/null 2>&1; then echo "plugin ok: $plugin"
      else claude plugin install "$plugin" --scope user </dev/null || echo "FAILED plugin $plugin"; fi
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
        (cd "$CLAUDE_HOME/skills/gstack" && ./setup --host claude --no-prefix -q) || echo "FAILED gstack setup"
      else
        echo "MISSING bun -- gstack cloned but not set up; install bun, then: cd ~/.claude/skills/gstack && ./setup --host claude --no-prefix -q"
      fi
    fi
    clone_once https://github.com/emilkowalski/skills.git "$CLAUDE_HOME/vendor/emilkowalski-skills" || true
    for d in "$CLAUDE_HOME/vendor/emilkowalski-skills/skills"/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      # -e follows a symlink, so a BROKEN one (the source dir moved or was
      # never cloned) fails it and ln then errors into set -e, aborting the
      # whole install. -L catches it whether or not it currently resolves.
      [ -e "$CLAUDE_HOME/skills/$name" ] || [ -L "$CLAUDE_HOME/skills/$name" ] || ln -s "${d%/}" "$CLAUDE_HOME/skills/$name"
    done
  fi
  if ! command -v npx >/dev/null; then echo "MISSING npx -- skipped $(wc -l < "$HERE/skills.tsv" | tr -d ' ') skills in skills.tsv"; return 0; fi
  while IFS=$'\t' read -r src skill; do
    [ -n "$skill" ] || continue
    [ -e "$HOME/.agents/skills/$skill" ] && continue
    npx -y skills add "$src" -g -a claude-code -s "$skill" -y </dev/null || echo "FAILED skill $skill"
  done < "$HERE/skills.tsv"
}

wire_integrations() {
  local c
  # herdr and graphify each install their own Claude integration; the file they
  # write is theirs ("managed by herdr; reinstalling overwrites this file").
  if command -v herdr >/dev/null && [ ! -f "$CLAUDE_HOME/hooks/herdr-agent-state.sh" ]; then
    herdr integration install claude
  fi
  # graphify's `install --platform claude` only wires the SKILL. The binary is a
  # PyPI package (`graphifyy`, two y's) that nothing here installed, so a fresh
  # machine skipped graphify entirely and said so in one MISSING line nobody
  # read. uv comes from the mise tool list in shared/config/mise/config.toml.
  # Userspace only: this writes to ~/.local, never through pacman. install.sh's
  # "never install unasked" stance is about SYSTEM packages -- install_skills
  # already clones repos and npx-installs without asking.
  if ! command -v graphify >/dev/null && command -v uv >/dev/null; then
    uv tool install graphifyy || echo "FAILED graphify install (uv tool install graphifyy)"
    hash -r 2>/dev/null || true
  fi
  if command -v graphify >/dev/null && [ ! -e "$CLAUDE_HOME/skills/graphify" ]; then
    graphify install --platform claude
  fi
  # rtk needs no install step: its Claude hook is the `rtk hook claude` command
  # in settings.base.json, and RTK.md is tracked in shared/claude/. `rtk init -g`
  # is deliberately NOT run -- it appends to CLAUDE.md, which is a linked file here.
  for c in rtk graphify herdr bun npx; do
    command -v "$c" >/dev/null || echo "MISSING $c (optional; the hook or skill that needs it stays inert)"
  done
}

if [ "$OFFLINE" = 1 ]; then
  echo "DOTFILES_OFFLINE=1 -- skipped plugins, skills, integrations"
  merge_settings
else
  install_plugins
  install_skills
  wire_integrations
  merge_settings
fi
