# No personal information in git — KEY INVARIANT

Load this when: writing or editing ANY tracked file in this repo (docs, compose files, scripts), or
whenever a Write/Edit/Bash tool call is unexpectedly blocked with a message from
`check-no-personal-info.sh`.

**This repo must never have personal information committed to it.** That means, outside of the gitignored
`.env`: no real domain name, no real external/host IPs, no real host usernames or absolute host file paths,
no secrets of any kind. This applies to documentation and `.claude/` reference material as much as it applies
to compose files — a leaked domain in a markdown file is exactly as bad as one in a `.yml`.

This is a standing priority, not a one-time cleanup task — treat it as active on every single edit, not
something to check at the end.

## The guard

A `PreToolUse` hook (`.claude/settings.json` → `.claude/hooks/check-no-personal-info.sh`) runs before every
`Write`, `Edit`, and `Bash` tool call in this project and **blocks** it if the content being written/run
contains:

- The literal value of `.env`'s `DOMAIN_NAME`, `MAIN_HOST_IP`, `REVERSE_PROXY_HOST_IP`, or (if set)
  `HOST_USERNAME` — the guard reads these from the gitignored `.env` at check time, so it always tracks
  whatever your real values currently are without them being written down anywhere else.
- An absolute path under `/home/<name>/` or `/Users/<name>/`, unless `<name>` is `dev` (the sandbox's fixed,
  documented, non-personal user — see `sandbox/README.md`) or the path follows this repo's own
  `/path/to/...` placeholder convention (see `secrets-and-env.md`).

When it blocks something, the reason names *which* `.env` variable or path pattern matched — deliberately
never the matched value itself, so the guard's own messages don't leak the secret into the transcript/logs
it's trying to keep the secret out of.

Self-test: `.claude/hooks/tests/run-hook-tests.sh` (also run automatically by `sandbox/setup.sh`, step 4)
exercises the guard against a fixture `.env`, never the real one. Run it after editing the hook.

## What the guard does NOT catch

This is a backstop, not a substitute for care — it only knows what it's told to look for:

- A real IP or hostname that isn't `DOMAIN_NAME`/`MAIN_HOST_IP`/`REVERSE_PROXY_HOST_IP` (e.g. a LAN device IP
  typed ad hoc, or a third external IP) has no needle to match against and will sail through.
- Paraphrased, split-across-lines, or differently-cased occurrences of a real value may not match a literal
  `grep -F`.
- Real personal info that isn't a domain/IP/path — a real name, a phone number, a physical address — isn't
  checked at all.

So: still think before writing. The guard catches the common, mechanical slip (copy-pasting a real value
where a template placeholder belongs); it is not a reason to stop checking your own work.

## If the guard blocks something that's actually fine (false positive)

- If it's a legitimate `/home/<name>/` or `/Users/<name>/` reference (e.g. documenting a *different*
  person's unrelated setup, or a name that happens to collide with your `HOST_USERNAME`), rephrase to avoid
  the absolute path, or use the `/path/to/...` placeholder convention instead.
- If `.claude/hooks/check-no-personal-info.sh` itself needs a new exception (e.g. another generic,
  non-personal username besides `dev`), edit the script's exclusion list, add a corresponding case to
  `.claude/hooks/tests/run-hook-tests.sh`, and re-run the self-test before relying on the change.
- Never work around a block by disabling the hook, editing `.claude/settings.json` to remove it, or asking to
  bypass permissions for the specific call — fix the content, or fix the guard properly (with a test), not
  the enforcement.

## Setting it up on a fresh clone

The hook is wired in tracked `.claude/settings.json`, so it's active as soon as Claude Code loads this
project — no separate install step. If you've just added or edited `.env`, the guard picks up the new values
immediately (it re-reads `.env` on every check, nothing is cached).
