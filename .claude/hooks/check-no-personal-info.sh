#!/usr/bin/env bash
# PreToolUse guard: blocks Write/Edit/Bash tool calls that would introduce
# personal information (real domain, real host IPs, real absolute host paths)
# into this repo. See .claude/reference/no-personal-info.md.
#
# Reads the real values to guard from .env (gitignored, never committed) -
# this script itself never writes to, or reads secrets out to, anywhere else.
# Override the env file with PERSONAL_INFO_ENV_FILE (used by the test harness
# in tests/run-hook-tests.sh so tests never touch the real .env).
set -uo pipefail

INPUT="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

HAYSTACK=""
case "$TOOL_NAME" in
  Write|Edit)
    HAYSTACK="$(printf '%s' "$INPUT" | jq -r '
      .tool_input | [(.content // ""), (.new_string // ""), (.old_string // ""), (.file_path // "")] | join("\n")
    ' 2>/dev/null)"
    ;;
  Bash)
    HAYSTACK="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$HAYSTACK" ] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_ROOT" ] && REPO_ROOT="/work"
ENV_FILE="${PERSONAL_INFO_ENV_FILE:-$REPO_ROOT/.env}"

get_env_val() {
  local key="$1"
  [ -f "$ENV_FILE" ] || return 0
  grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n1 | sed -E "s/^${key}=//; s/^\"(.*)\"\$/\1/"
}

# Known .env.template placeholder values - never treated as "real" even if
# somehow present under these keys.
is_placeholder() {
  case "$1" in
    ""|example.com|https://status.example.com|123.45.67.*) return 0 ;;
    *) return 1 ;;
  esac
}

needle_keys=()
needle_vals=()
for key in DOMAIN_NAME MAIN_HOST_IP REVERSE_PROXY_HOST_IP HOST_USERNAME; do
  val="$(get_env_val "$key")"
  if ! is_placeholder "$val"; then
    needle_keys+=("$key")
    needle_vals+=("$val")
  fi
done

# Deliberately never echo the matched VALUE back in the deny reason below -
# that would print the secret itself into the transcript/log every time the
# guard fires. Only the .env KEY NAME that matched is reported.
violation=""
i=0
for needle in ${needle_vals[@]+"${needle_vals[@]}"}; do
  if [ -n "$needle" ] && printf '%s' "$HAYSTACK" | grep -qF -- "$needle" 2>/dev/null; then
    violation="the real value of .env's ${needle_keys[$i]} - that must only ever live in .env"
    break
  fi
  i=$((i + 1))
done

if [ -z "$violation" ]; then
  # Generic absolute host path: /home/<name>/ or /Users/<name>/, excluding the
  # sandbox's fixed generic 'dev' user (documented convention, not personal).
  # The matched segment (a real username) is redacted before it's ever
  # reported, same reasoning as the .env values above.
  hit="$(printf '%s' "$HAYSTACK" | grep -oE '/(home|Users)/[A-Za-z0-9_.-]+/' 2>/dev/null | grep -vE '/(home|Users)/dev/' 2>/dev/null | head -n1 || true)"
  if [ -n "$hit" ]; then
    redacted="$(printf '%s' "$hit" | sed -E 's#^/(home|Users)/[^/]+/#/\1/***/#')"
    violation="an absolute host path ('$redacted') outside the documented /path/to/ placeholder convention"
  fi
fi

if [ -n "$violation" ]; then
  reason="BLOCKED by check-no-personal-info.sh: this change contains $violation. See .claude/reference/no-personal-info.md for what to do."
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg reason "$reason" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"personal-info guard tripped (jq unavailable for full message)"}}'
  fi
fi

exit 0
