#!/usr/bin/env bash
# SessionStart hook: inject HANDOFF.md into context after /clear or /compact.
# stdin: JSON with source, cwd

set -euo pipefail
# Fail-open: any uncaught error (e.g. malformed JSON on stdin) exits 0 so the hook
# never aborts session start.
trap 'exit 0' ERR

input=$(cat)

source_val=$(printf '%s' "$input" | jq -r '.source // ""')

# Only act on clear or compact
if [ "$source_val" != "clear" ] && [ "$source_val" != "compact" ]; then
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
handoff_file="${cwd}/HANDOFF.md"

if [ ! -f "$handoff_file" ]; then
  exit 0
fi

# Emit the HANDOFF.md content as additionalContext using --rawfile for safe embedding
jq -n \
  --rawfile handoff "$handoff_file" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$handoff}}'
exit 0
