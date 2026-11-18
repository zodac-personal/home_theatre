#!/bin/bash
# ------------------------------------------------------------------------------
# Script Name:  update_dependency_versions.sh
#
# Description:  Updates the pinned versions of the AI SANDBOX (the disposable container Claude Code runs
#               in when working on this repo) - and nothing else:
#                 - The ai-sandbox submodule (the launcher and its shared base image): to its highest
#                   X.Y.Z release tag, by the submodule's own `sandbox.sh update`, which then runs that
#                   version's `init` (new templates, the organisation rules import, .claude/settings.json)
#                 - ai-sandbox-configuration/Dockerfile (this repo's layer on top of that base): every
#                   `FROM image:tag` within its major, and every package in its BEGIN/END DEBIAN PACKAGES
#                   block, by the submodule's `sandbox.sh update-versions --project-only` - resolved
#                   against the (just updated) base's Debian release, the one the sandbox actually runs
#               Then builds the sandbox image, to prove the new pins still install (Debian drops a
#               superseded package version from its repositories, so a dead pin fails the next build).
#
#               It deliberately does NOT touch the deployed stack: compose/ (the services' pinned images
#               are bumped by hand and upgraded per .claude/reference/upgrades.md), the root
#               docker-compose*.yml files, or docker/**. As a guard, compose/ is fingerprinted before and
#               after, and the run fails if anything in it changed.
#
# Usage:        .github/scripts/update_dependency_versions.sh [--no-build]
#                 --no-build  skip the final `ai-sandbox/sandbox.sh build`
#
# Requirements: bash, git, curl, jq, docker, GNU sed/sort (the submodule's updater pulls images and
#               queries apt in a throwaway container)
#
# Nothing is committed: review and commit the moved submodule, the Dockerfile and anything `init` added.
# ------------------------------------------------------------------------------

set -euo pipefail

AI_SANDBOX_DIR="ai-sandbox"
SANDBOX_DOCKERFILE="ai-sandbox-configuration/Dockerfile"
# Never modified by this script - checked at the end
PROTECTED_DIR="compose"

usage() {
    sed -n '2,/^# ---.*$/{/^# ---/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}" | sed '/^-*$/d'
}

build=1
while [[ "$#" -gt 0 ]]; do
    case "${1}" in
        --no-build) build=0 ;;
        -h|--help)  usage; exit 0 ;;
        *)          echo "❌ Unknown option: ${1} (see --help)" >&2; exit 1 ;;
    esac
    shift
done

# Always run from the repository root, wherever the script is invoked from
cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

for tool in git curl jq docker; do
    command -v "${tool}" >/dev/null 2>&1 || { echo "❌ Missing required tool: ${tool}" >&2; exit 1; }
done

# A content fingerprint of every file under compose/ - independent of git, so it also catches a change to a
# file with local edits already in progress.
fingerprint_protected() {
    find "${PROTECTED_DIR}" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1
}

submodule_version() {
    git -C "${AI_SANDBOX_DIR}" describe --tags --exact-match 2>/dev/null || git -C "${AI_SANDBOX_DIR}" rev-parse --short HEAD
}

UPDATE_SUMMARY=()

protected_before=$(fingerprint_protected)
dockerfile_before=$(sha256sum "${SANDBOX_DOCKERFILE}" | cut -d' ' -f1)

# ── 1. The ai-sandbox submodule ───────────────────────────────────────────────
# First, so the project's packages below resolve against the base (and updater) of the new tag.
echo
echo "🔍 Updating the ${AI_SANDBOX_DIR} submodule to its newest release..."
if [[ ! -x "${AI_SANDBOX_DIR}/sandbox.sh" ]]; then
    git submodule update --init "${AI_SANDBOX_DIR}"
fi
sandbox_before=$(submodule_version)
# Refuses (non-zero) if the submodule has local changes; it never commits.
"${AI_SANDBOX_DIR}/sandbox.sh" update
sandbox_after=$(submodule_version)
if [[ "${sandbox_before}" != "${sandbox_after}" ]]; then
    UPDATE_SUMMARY+=("${AI_SANDBOX_DIR}: ${sandbox_before} → ${sandbox_after}")
    echo "✅ ${AI_SANDBOX_DIR} moved to ${sandbox_after}"
else
    echo "  ${AI_SANDBOX_DIR} already on ${sandbox_after} (up-to-date)"
fi

# ── 2. This repo's sandbox layer ──────────────────────────────────────────────
# --project-only: the base's pins belong to the ai-sandbox repo and arrive with its tags; bumping them here
# would dirty the submodule and block its next move.
echo
echo "🔍 Updating the pins in ${SANDBOX_DOCKERFILE}..."
"${AI_SANDBOX_DIR}/sandbox.sh" update-versions --project-only
if [[ "$(sha256sum "${SANDBOX_DOCKERFILE}" | cut -d' ' -f1)" != "${dockerfile_before}" ]]; then
    UPDATE_SUMMARY+=("${SANDBOX_DOCKERFILE}: pins updated (see git diff)")
fi

# ── 3. The guard: the deployed stack is untouched ─────────────────────────────
if [[ "$(fingerprint_protected)" != "${protected_before}" ]]; then
    echo "❌ ${PROTECTED_DIR}/ changed during this run - this script must never modify it. Inspect and revert:" >&2
    git status --short -- "${PROTECTED_DIR}" >&2
    exit 1
fi

# ── 4. Prove the new pins install ─────────────────────────────────────────────
if (( build == 1 )); then
    echo
    echo "🔨 Building the sandbox image to prove the new pins install..."
    "${AI_SANDBOX_DIR}/sandbox.sh" build
    echo "✅ Sandbox image builds"
else
    echo
    echo "⚠️ Build skipped (--no-build) - run '${AI_SANDBOX_DIR}/sandbox.sh build' before committing"
fi

echo
echo "📋 Changes made:"
if [[ "${#UPDATE_SUMMARY[@]}" -eq 0 ]]; then
    echo "   (none)"
else
    printf '   - %s\n' "${UPDATE_SUMMARY[@]}"
fi
git status --short -- "${AI_SANDBOX_DIR}" ai-sandbox-configuration .run .claude
