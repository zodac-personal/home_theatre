# Secrets & environment variables

Load this when: adding a new configurable value, adding a new service that needs credentials, or touching
`.env.template`.

## `.env` vs `.env.template`

- `.env.template` is tracked and is the source of truth for *which* variables exist, with placeholder/example
  values and inline comments explaining format or where to obtain a real value (e.g. API key URLs, timezone
  database link).
- `.env` is the real secrets file, gitignored, created by copying and filling in the template.
- Every variable a compose file references should have a corresponding entry in `.env.template`, even if the
  real value is a long-lived secret with no sensible placeholder (use a descriptive dummy like
  `"traefikProviderPassword"`).
- The single flat `.env.template` is itself acknowledged as provisional — its first line is
  `# TODO: Split into different .env files (base + application)`, and it's the owner's #1 current priority
  (see `.claude/CLAUDE.md`'s "Current priorities"), not just a stray comment. Don't treat the current
  one-file layout as a settled design to defend; if you're adding a large batch of new variables, it's worth
  asking whether this is the moment that split happens rather than growing the single file further.

## Required-variable guard pattern

Compose files use `${VAR:?[service] message}` (not a plain `${VAR}`) for anything that must be set:

```yaml
POSTGRES_PASSWORD: "${TANDOOR_DB_PASSWORD:?[tandoor] Database password missing}"
```

This fails `docker compose up` fast with a clear error instead of starting the container misconfigured
(e.g. Postgres with an empty password). Follow this pattern for any new required variable — the `[service]`
prefix matters when several services fail at once. Variables with a sensible default use `${VAR:-default}`
instead (e.g. `AUTHELIA_EXTERNAL_PORT:-9091`).

## Keeping secrets out of `docker inspect` / process listings

`environment:` values are visible via `docker inspect`, `/proc/<pid>/environ`, and crash dumps. Two patterns
in this repo address that for the cases that matter most:

- **Redis/Valkey password indirection** (`compose/traefik.yml`): the static Traefik config file carries a
  `__REDIS_PASSWORD__` placeholder; at container start, a shell command substitutes the real value from an
  env var into a copy of the config written to tmpfs (`/tmp`, never disk), using `$$` so the substitution
  happens in the *container's* shell rather than being expanded by Compose (which would put the secret in the
  command string itself, visible via `docker inspect`).
- **What's *not* yet done**: Authelia's secrets (`SESSION_SECRET`, `STORAGE_ENCRYPTION_KEY`, `OIDC_HMAC_SECRET`,
  `BACKEND_PASSWORD`, `ADMIN_PASSWORD`, `SMTP_APP_PASSWORD`) are still passed as plain `environment:` values.
  This is a tracked, open item — see `.claude/SECURITY_TODO.md` #11 (switch to the `AUTHELIA_*_FILE` variants
  fed by `secrets:` or a read-only mount). If you're touching Authelia's secret handling, that's the item to
  read first; don't reinvent the approach independently.

## User/group IDs

- `PUID_ROOT` / `PGID_ROOT` (`0:0`) — only for containers that genuinely need root (document why in a
  comment next to the `user:` line).
- `PUID_NON_ROOT` / `PGID_NON_ROOT` (`1000:1000` by default) — the default for everything else on Main/SER.
- `PUID_NON_ROOT_ORACLE` / `PGID_NON_ROOT_ORACLE` (`1001:1001` by default) — separate ID space for the Oracle
  host, since it's a different machine with its own user namespace.

## Directory mount variables

Host media/data directories (`MOVIE_DIRECTORY`, `MUSIC_DIRECTORY`, `TV_SHOWS_DIRECTORY`, etc.) are defined
once in `.env`/`.env.template` and referenced from whichever compose file needs them, rather than hardcoding
paths per service. When adding a service that needs a new category of host directory, add the variable to
`.env.template` with a comment describing the expected structure (see `ROM_GAMES_AND_BIOS_PARENT_DIRECTORY`
for an example of documenting an expected sub-layout).
