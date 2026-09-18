#!/usr/bin/env bash
# Self-test for check-no-personal-info.sh - proves the personal-info guard
# actually blocks/allows as intended, using a fixture .env so the REAL .env
# is never read or touched. Run via sandbox/setup.sh step 4, or manually
# after editing the hook. Exits non-zero if any case fails.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../check-no-personal-info.sh"

TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT
cat > "$TMP_ENV" <<'EOF'
DOMAIN_NAME="test-fixture-domain.example"
MAIN_HOST_IP="198.51.100.42"
REVERSE_PROXY_HOST_IP="198.51.100.43"
HOST_USERNAME="testfixtureuser"
EOF
export PERSONAL_INFO_ENV_FILE="$TMP_ENV"

pass=0
fail=0

run_case() {
  local desc="$1" payload="$2" expect="$3"  # expect: "deny" or "allow"
  local output decision
  output="$(printf '%s' "$payload" | "$HOOK" 2>&1)"
  if printf '%s' "$output" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    decision="deny"
  else
    decision="allow"
  fi
  if [ "$decision" = "$expect" ]; then
    pass=$((pass + 1))
    printf '  ok   - %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf '  FAIL - %s (expected %s, got %s; output: %s)\n' "$desc" "$expect" "$decision" "$output"
  fi
}

run_case "blocks a leaked domain in a Write" \
  '{"tool_name":"Write","tool_input":{"file_path":"README.md","content":"see https://monitor.test-fixture-domain.example for status"}}' \
  "deny"

run_case "blocks a leaked host IP in an Edit" \
  '{"tool_name":"Edit","tool_input":{"file_path":"compose/foo.yml","old_string":"a","new_string":"bind: 198.51.100.42"}}' \
  "deny"

run_case "blocks a leaked real username path in a Bash command" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hi > /home/testfixtureuser/notes.txt"}}' \
  "deny"

run_case "blocks a generic personal home path even without a known username" \
  '{"tool_name":"Write","tool_input":{"file_path":"docker-compose-test.yml","content":"- /home/someoneelse/Downloads:/library"}}' \
  "deny"

run_case "allows the sandbox generic dev user path" \
  '{"tool_name":"Write","tool_input":{"file_path":"sandbox/README.md","content":"mounted at /home/dev/.claude"}}' \
  "allow"

run_case "allows the documented /path/to placeholder convention" \
  '{"tool_name":"Write","tool_input":{"file_path":".env.template","content":"MOVIE_DIRECTORY=\"/path/to/movies/\""}}' \
  "allow"

run_case "allows unrelated clean content" \
  '{"tool_name":"Edit","tool_input":{"file_path":"README.md","old_string":"a","new_string":"b"}}' \
  "allow"

run_case "ignores non-matching tools" \
  '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' \
  "allow"

echo
if [ "$fail" -eq 0 ]; then
  echo "All $pass cases passed"
  exit 0
else
  echo "$fail of $((pass + fail)) cases FAILED"
  exit 1
fi
