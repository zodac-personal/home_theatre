# syntax=docker/dockerfile:1.7
# home_theatre's layer of the sandbox image: the tools it needs on top of the shared base (Debian 13,
# nested Docker + compose plugin, Node, git, gh, jq, python3 - see ai-sandbox/image/base/Dockerfile,
# whose pins belong to that repo). Claude Code and the sandbox scripts are added ABOVE this layer, so
# a Claude release never rebuilds anything here. Built by ai-sandbox/sandbox.sh with this directory
# as the build context.
#
# This repo is Compose files, Dockerfiles, shell scripts and Markdown, so the base covers nearly all of
# it: the nested Docker runs `docker compose config` and the linters' images (hadolint,
# markdownlint-cli2) without touching the host daemon. The old in-repo sandbox also carried a JDK,
# Maven, Playwright and an image-asset toolchain inherited from another project; none were used here,
# so they were dropped in the move to ai-sandbox.
#
# The pins are bumped by .github/scripts/update_dependency_versions.sh, which keeps the BEGIN/END
# DEBIAN PACKAGES block's shape (one `name="version" \` per line, both --mount flags on the RUN line).

ARG BASE_IMAGE

FROM ${BASE_IMAGE}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# shellcheck: lints the Claude hook guards (.claude/hooks/) and the repo's scripts.
# hadolint ignore=DL3009
# BEGIN DEBIAN PACKAGES
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -yqq --no-install-recommends \
        shellcheck="0.10.0-1"
# END DEBIAN PACKAGES
