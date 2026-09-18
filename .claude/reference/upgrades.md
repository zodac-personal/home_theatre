# Upgrade paths

Load this when: bumping an image version, or performing a DB major-version upgrade.

## Bumping a pinned image version

1. Check the release notes URL already in the image's comment (`image: foo:1.2.3  # https://.../releases`)
   for breaking changes.
2. Update the version pin and the comment stays pointed at the same releases page.
3. Prefer stable tags over pre-release/nightly/dev tags for anything internet-facing. Several *arr images
   currently run nightly/develop tags behind Authelia's broad API bypass — a tracked risk, not a pattern to
   extend (`.claude/SECURITY_TODO.md`, Medium section).
4. `docker compose up --build -d <service> --wait` to apply, then check the healthcheck goes green and check
   logs before considering it done.

## Database major-version upgrades

Several services run their own Postgres (or PostGIS) instance as a `-db` sidecar. README.md has a full,
copy-pasteable runbook per service (Authelia, Diurnal, Reitti, Jellystat, Linkwarden, LLDAP, RomM, SonarQube,
SpeedTest) — read the relevant section there rather than reconstructing the steps here, since the exact
`pg_dump`/`pg_restore` flags and `docker compose down` service lists differ slightly per service (some use
`-cC` plain-SQL dumps, some use `-Fc` custom-format dumps with `pg_restore --clean --if-exists`).

The shared shape across all of them:

1. `source .env` so `${SERVICE_DB_USER}` etc. are available in the shell.
2. Dump the current database *before* touching anything else.
3. `docker compose down <service> <service>-db` (and any cache/tile-cache sidecars).
4. Bump the Postgres/PostGIS image version in `compose/<service>.yml`.
5. **Delete (after copying elsewhere) the storage directory** for `<service>-db` — Postgres major-version
   upgrades aren't in-place; the data directory format changes.
6. Bring up only the new `-db` container with `--wait`, restore the dump into it, then bring up the
   application container(s).

Don't skip step 2 or step 5's "copy elsewhere first" — there's no automated rollback if the restore fails
partway through.

## New service, not an upgrade

Adding a brand-new service isn't covered here — see `compose-hardening.md` for the baseline every service
needs and `reverse-proxy-and-auth.md` for exposing it through Traefik/Authelia.
