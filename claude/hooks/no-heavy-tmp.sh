#!/usr/bin/env bash
# PreToolUse(Bash): block heavy installs/clones into /tmp (tmpfs = RAM).
# Misses tool caches written under $TMPDIR and `cd /tmp/x` then `npm ci`;
# the tmp.mount size cap is the backstop for those.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
heavy='(npm (ci|install|i)\b|pnpm (install|i)\b|yarn( install)?\b|git worktree add|git clone|npx expo install)'
if grep -Eq "$heavy" <<<"$cmd" && grep -Eq '(^|[^[:alnum:]_./-])/tmp/' <<<"$cmd"; then
  echo "Blocked: heavy install/clone into /tmp (tmpfs = RAM). Use a disk path: \$HOME/.cache/claude-work or the repo's .claude/worktrees/." >&2
  exit 2
fi
exit 0
