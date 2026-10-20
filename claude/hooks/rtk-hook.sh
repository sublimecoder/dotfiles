#!/usr/bin/env bash
# RTK PreToolUse wrapper. In a worktree-isolated session (cwd under
# .claude/worktrees/) Claude Code refuses any `rtk git ...` it cannot prove
# stays inside the worktree, so leave git commands unrewritten there.
# Everything else (and git everywhere else) still goes through RTK.
command -v rtk >/dev/null 2>&1 || exit 0
input=$(cat)
if printf '%s' "$input" | jq -e '
    ((.cwd // "") | test("/\\.claude/worktrees/"))
    and ((.tool_input.command // "") | test("(^|[;&|(]|\\s)git\\s"))
  ' >/dev/null 2>&1; then
  exit 0
fi
printf '%s' "$input" | exec rtk hook claude
