# Compose service hardening baseline

Load this when: adding a new service to any `compose/*.yml`, or modifying an existing service's security-
relevant settings (`cap_add`/`cap_drop`, `user`, networks, `volumes`, resource limits).

This is the **target baseline** — the large majority of services meet it, but it is not a guarantee every
service does today; known exceptions are called out per-bullet below rather than glossed over. Match the
baseline for anything new regardless — a new service that's missing several of these is the fastest way to
add a fresh finding to `.claude/SECURITY_TODO.md`, not just reopen an old one.

## The checklist

- **Pin the image** to an exact version (never `latest`), with a comment linking to its release notes:
  `image: vabene1111/recipes:2.6.15  # https://github.com/TandoorRecipes/recipes/releases`
- **`cap_drop: [ALL]`** on every service. Add back only the specific capabilities actually needed via
  `cap_add` (e.g. Tandoor's `CHOWN`/`SETGID`/`SETUID` for its startup chown), never drop the blanket
  `cap_drop`. Known exception: `diurnal-db` is currently missing it (`.claude/SECURITY_TODO.md`, Medium) —
  don't copy that omission into a new service.
- **`security_opt: [no-new-privileges=true]`** on every service.
- **`tmpfs: ["/tmp:size=64m,noexec,nosuid,nodev"]`** — containers get a `/tmp` that's memory-backed and can't
  execute or hold setuid binaries. Add extra tmpfs mounts the same way if a service needs another
  ephemeral/writable path (e.g. Postgres containers also tmpfs `/var/run/postgresql`).
- **`deploy.resources.limits`** — set `cpus`, `memory`, and `pids` sized to what the service actually needs;
  copy from a comparable existing service rather than guessing generously.
- **`logging: {driver: json-file, options: {max-size, max-file}}`** — no unbounded log growth. `10m`/`3` for
  quiet services, `50m`/`5` for chatty ones like Traefik/Authelia.
- **Explicit non-root `user:`** — `${PUID_NON_ROOT}:${PGID_NON_ROOT}` for app containers, the image's own
  numeric uid/gid for images with a fixed non-root user (e.g. `999:999` for the `postgres` user,
  `999:1000` for `valkey`). The intent is: only use `${PUID_ROOT}:${PGID_ROOT}` when the image genuinely
  needs root, and say why in a comment — some services do this well (`traefik` explains its socket-access
  need; `tunarr` in `emby.yml` has `# root needed for MeiliSearch DB`; `tandoor` has a `# TODO: <upstream PR
  link>` marking it as a workaround for an upstream bug, not a permanent choice). Others run as
  `PUID_ROOT`/`PGID_ROOT_ORACLE` with **no** comment at all (`dash`, `dash-ser`, `uptime-kuma`, `reitti-db`,
  `reitti-tile-cache`, `traefik-agent`, `traefik-dashboard`) — that may be because the image genuinely
  requires it, or may just be undocumented; don't treat "this existing service runs as root" as proof it's
  necessary when copying a pattern to a new service.
  A third pattern, distinct from both: `homarr` and `lldap` have their `user:` line present but
  **commented out**, with `# Doesn't work, must use environment variables` — those images take `PUID`/`PGID`
  as environment variables instead of accepting a Compose `user:` override, so privilege-dropping happens
  inside the container rather than via Compose. If a new service's `user:` override causes startup failures,
  check whether its image expects `PUID`/`PGID` env vars instead before assuming it needs root.
- **Healthcheck** — a `CMD`/`CMD-SHELL` check appropriate to the service, with `interval`/`retries`/
  `start_period`/`timeout`. This is the intent, not the current reality: `authelia`, `diurnal`, `filebrowser`,
  `homebox`, `jellystat`, `linkwarden`, `lldap`, `netalert`, `ottrbox`, `sportarr`, and `uptime-kuma` currently
  have none. `lldap` is the one tracked case (`.claude/SECURITY_TODO.md` #12) because `authelia` depends on
  it with `condition: service_healthy` — a `depends_on` health condition on a service with no healthcheck
  will simply never become "healthy" per Compose, so check for that combination before assuming a new
  `depends_on` will work as written.

## Networking

- Give the service its own bridge network in `networks:` at the top of the file, named to match
  (`name: <service>`).
- If the service has a DB or cache tier, put it on a **second, `internal: true`** network
  (`<service>-internal`) with no egress — the app container joins both networks, the DB/cache only joins the
  internal one. This is why a compromised DB container can't reach the internet or unrelated services.
- Only publish a `ports:` mapping if the service must be reached from outside Docker (e.g. by Traefik running
  on a different host, or a LAN client). Bind to a specific host IP (`${REVERSE_PROXY_HOST_IP}:6379:6379`)
  rather than leaving it on `0.0.0.0` unless it genuinely needs to be reachable from every interface — Oracle's
  Uptime Kuma binding to `0.0.0.0` alongside its Traefik is a tracked example of getting this wrong
  (`.claude/SECURITY_TODO.md` #8).
- Services that don't need to be reached from outside their own network use `expose:` instead of `ports:`.

## Storage

- Persistent data goes under `../storage/<service>/...` as a **bind mount**, not a named volume, unless the
  image specifically requires a volume. This keeps all state visible and directly backup-able from the host
  filesystem (see README's backup section) rather than hidden inside Docker's volume store.
- Mount read-only config (`:ro`) wherever the container doesn't need to write to it.

## Read-only root filesystem

`read_only: true` is used exactly once so far (NetAlertX) but works well for any stateless service (Traefik,
Traefik-kop, Authelia, Dozzle, Apprise, Whisper, FlareSolverr are flagged as easy candidates in
`.claude/SECURITY_TODO.md`). If you're adding a new stateless service, consider setting it there rather than
waiting for a follow-up pass.
