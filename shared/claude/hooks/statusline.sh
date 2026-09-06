#!/bin/bash
# Statusline: model | layer badge | git branch | context % | cost | caveman/ponytail badges.
# Runs on every keystroke — keep it to one jq pass, one awk lookup, two git calls.
# ponytail: basic 16-color SGR only (30-37/90-97) — the renderer ignores 256-color \033[38;5;Nm.
input=$(cat)

model=""; dir=""; cost=""; pct=""
if [ -n "$input" ] && command -v jq >/dev/null; then
  eval "$(printf '%s' "$input" | jq -r '
    "model=" + ((.model.display_name // "") | @sh),
    "dir="   + ((.workspace.current_dir // .cwd // "") | @sh),
    "cost="  + ((.cost.total_cost_usd // empty | tostring) | @sh),
    "pct="   + ((.context_window.used_percentage // empty | floor | tostring) | @sh)
  ' 2>/dev/null)"
fi

parts=()
dim() { printf '\033[37m%s\033[0m' "$1"; }

# Model — red when the main loop drifted off the effort-table default (Opus 5).
# Fable is an xhigh escalation, not a default; Sonnet/Haiku belong in subagents.
if [ -n "$model" ]; then
  case "$model" in
    Opus*) parts+=("$(printf '\033[1m%s\033[0m' "$model")") ;;
    *)     parts+=("$(printf '\033[1;91m%s !\033[0m' "$model")") ;;
  esac
fi

# Identity layer badge via the vault's single manifest reader
if [ -n "$dir" ]; then
  layer=$("${AIOS_VAULT:-$HOME/code/aios-vault}/AIOS/Systems/resolve-project.sh" "$dir" 2>/dev/null | awk -F= '/^LAYER=/{print $2}')
  case "$layer" in
    creator)      parts+=("$(printf '\033[95m[CREATOR]\033[0m')") ;;
    professional) parts+=("$(printf '\033[94m[PRO]\033[0m')") ;;
    work)         parts+=("$(printf '\033[91m[WORK]\033[0m')") ;;
  esac
fi

# Git branch + dirty star (tracked files only — untracked scan too noisy/slow)
if [ -n "$dir" ]; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    star=""
    git -C "$dir" diff --quiet --ignore-submodules HEAD 2>/dev/null || star="*"
    parts+=("$(printf '\033[36m%s\033[0m' "${branch}${star}")")
  fi
fi

# Context % — red at 80%+
if [ -n "$pct" ]; then
  if [ "$pct" -ge 80 ] 2>/dev/null; then
    parts+=("$(printf '\033[91m%s%%\033[0m' "$pct")")
  else
    parts+=("$(dim "${pct}%")")
  fi
fi

[ -n "$cost" ] && parts+=("$(printf '\033[32m%s\033[0m' "$(printf '$%.2f' "$cost")")")

# Plugin badges — glob latest cached version so plugin updates don't break the path
cave=$(ls -1 "$HOME"/.claude/plugins/cache/caveman/caveman/*/src/hooks/caveman-statusline.sh 2>/dev/null | tail -1)
pony=$(ls -1 "$HOME"/.claude/plugins/cache/ponytail/ponytail/*/hooks/ponytail-statusline.sh 2>/dev/null | tail -1)
for s in "$cave" "$pony"; do
  [ -n "$s" ] || continue
  b=$(bash "$s" </dev/null)
  [ -n "$b" ] && parts+=("$b")
done

sep=$(printf '\033[97m|\033[0m')
out=""
for p in "${parts[@]}"; do out="${out:+$out $sep }$p"; done
printf '%s' "$out"
