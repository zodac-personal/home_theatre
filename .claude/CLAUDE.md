# home_theatre

A self-hosted homelab: Docker Compose stacks for media (`*arr` suite, Emby, Navidrome, AudiobookShelf, RomM,
...), household apps (Tandoor recipes, Homebox, DailyTxT, Linkwarden, ...), and the platform services that
tie them together (Traefik, Authelia, LLDAP, monitoring), spread across three hosts. `README.md` has the full
service catalogue and auth-integration matrix — start there for "what does this app do / how do I use it".

This file is deliberately just an index. Don't read every file below speculatively — load only the one(s)
relevant to the task in front of you; each is written to stand alone once loaded.

## KEY INVARIANT: no personal information in git

This is the one rule that applies to every single edit, unconditionally, regardless of what task you're
doing: **no personal information — real domain name, real host IPs, real host usernames/paths, secrets of
any kind — ever gets committed to this repo.** Outside the gitignored `.env`, only placeholder/example values
belong in tracked files (docs included — `.claude/` itself is not exempt).

This is enforced by a live `PreToolUse` hook, not just a written rule — see
[`no-personal-info.md`](reference/no-personal-info.md) before assuming a blocked Write/Edit/Bash call is a
bug. The hook is a backstop with known blind spots (it only catches values it's told to look for), so it does
not replace thinking about this on every edit.

## Reference docs (`.claude/reference/`)

| Load this file... | ...when you're about to |
|---|---|
| [`no-personal-info.md`](reference/no-personal-info.md) | A Write/Edit/Bash call gets blocked unexpectedly, or you're adjusting the guard itself |
| [`deployment-topology.md`](reference/deployment-topology.md) | Add/move a service between hosts, touch `traefik-kop`/the Redis provider, or need repo-layout orientation |
| [`secrets-and-env.md`](reference/secrets-and-env.md) | Add a new env var, add a service needing credentials, or edit `.env.template` |
| [`compose-hardening.md`](reference/compose-hardening.md) | Add a new service to any `compose/*.yml`, or touch an existing service's security settings (caps, user, networks, volumes, limits) |
| [`reverse-proxy-and-auth.md`](reference/reverse-proxy-and-auth.md) | Expose a service through Traefik, or edit `docker/authelia/config/configuration.yml` |
| [`upgrades.md`](reference/upgrades.md) | Bump a pinned image version, or do a DB major-version upgrade |
| [`ci-and-linting.md`](reference/ci-and-linting.md) | Edit a Dockerfile, edit `README.md`, or touch the GitHub workflows |

## Security backlog

[`SECURITY_TODO.md`](SECURITY_TODO.md) is the live findings backlog from the most recent security review
(dated against a specific commit — check it's still current before treating an item as open or closed).
Check it whenever a change touches Traefik, Authelia, LLDAP, or any internet-facing router — several of the
reference docs above point at specific numbered items where they're directly relevant.

Baseline protections it assumes as already in place everywhere (don't regress these; see
[`compose-hardening.md`](reference/compose-hardening.md) for the full checklist): pinned images,
`cap_drop: ALL`, `no-new-privileges`, resource limits, log rotation, tmpfs `/tmp`, internal networks for
DB/cache tiers, TLS 1.3 + Cloudflare Authenticated Origin Pulls.

## Current priorities

In this order, per the owner (2026-09-17) — if asked what to work on, or whether something is worth doing
now, weigh it against this list rather than treating every open item as equally urgent:

1. **Split `.env`/`.env.template`** into base + per-application files — currently every app gets every value,
   which the owner wants to change next. See [`secrets-and-env.md`](reference/secrets-and-env.md).
2. **Work through `.claude/SECURITY_TODO.md`**, roughly in its stated order (Critical → High → Medium).
3. **Further hardening best-practices** beyond what's already in `SECURITY_TODO.md` — lower priority, revisit
   after 1 and 2. Don't assume that file is exhaustive; if you spot something while working on something
   else, it's worth a mention, but not worth stopping to fix unprompted.
4. **Reorganise `README.md`** into a proper, formal doc. It is currently, in the owner's own words, "a
   braindump of different apps and processes" — its multiple `TODO:` markers and unstructured Backups/Misc
   Info sections are known and expected, not oversights to quietly patch one at a time. Don't treat its
   current structure as a template to preserve when this work starts; ask what shape is wanted.

## Not covered here

- `sandbox/` (repo root) is a disposable Docker sandbox for running Claude Code itself against this repo —
  tooling for working on the repo, not part of the deployed stack. See `sandbox/README.md`.
- Backup procedures and per-service DB upgrade runbooks live in `README.md`, not duplicated here (except a
  short cross-host summary in [`upgrades.md`](reference/upgrades.md)) — due for the reorganisation above,
  so don't be surprised if their exact location/structure has moved.
