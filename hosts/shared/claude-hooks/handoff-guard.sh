#!/usr/bin/env bash
# Stop hook: block Claude session stop when context is large and HANDOFF.md is stale.
# stdin: JSON with transcript_path, cwd, stop_hook_active

set -euo pipefail
# Fail-open: any uncaught error (e.g. malformed JSON on stdin) exits 0 so a Stop
# hook never traps the user in an un-stoppable loop. if-conditions don't trip ERR,
# so the block path below is unaffected.
trap 'exit 0' ERR

input=$(cat)

# P0: if stop_hook_active is true, exit immediately to prevent infinite loop
stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')
if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // ""')

# Check if HANDOFF.md is fresh (mtime < 90s ago)
handoff_file="${cwd}/HANDOFF.md"
if [ -f "$handoff_file" ]; then
  now=$(date +%s)
  mtime=$(stat -c '%Y' "$handoff_file" 2>/dev/null || echo 0)
  age=$(( now - mtime ))
  if [ "$age" -lt 90 ]; then
    exit 0
  fi
fi

# Parse transcript JSONL to get token count from last assistant message with usage
token_count=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Reverse-scan the JSONL for the last assistant message that has .message.usage
  token_count=$(
    tac "$transcript_path" 2>/dev/null | \
    while IFS= read -r line; do
      result=$(printf '%s' "$line" | jq -r '
        select(.message.usage != null) |
        (
          (.message.usage.input_tokens // 0) +
          (.message.usage.cache_read_input_tokens // 0) +
          (.message.usage.cache_creation_input_tokens // 0) +
          (.message.usage.output_tokens // 0)
        )
      ' 2>/dev/null || true)
      if [ -n "$result" ] && [ "$result" != "null" ]; then
        printf '%s\n' "$result"
        break
      fi
    done
  ) || true
fi

# Default to 0 if empty or non-numeric
if ! [[ "$token_count" =~ ^[0-9]+$ ]]; then
  token_count=0
fi

# Check threshold
threshold="${HANDOFF_TOKEN_THRESHOLD:-120000}"
if [ "$token_count" -lt "$threshold" ]; then
  exit 0
fi

# Block: prompt user to write HANDOFF.md
reason="⚠️ Context 已達 ${token_count} tokens。結束前請寫/更新 ./HANDOFF.md,需涵蓋:① 當前任務與目標 ② 已修改檔案清單 ③ 未完成 TODO ④ 關鍵決策與踩過的坑 ⑤ 下一步具體動作。完成後即可正常結束。"
printf '%s' "$reason" | jq -R '{"decision":"block","reason":.}'
exit 0
