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
- **Explicit non-root `user:`, one ID per app** — see "Container user IDs" below for the convention and the
  ID list. Docker socket access never needs root: `group_add` the host's docker GID instead. Only use
  `${PUID_ROOT}:${PGID_ROOT}` when the image genuinely needs root, and say why in a comment (`tunarr` in
  `emby.yml`: `# root needed for MeiliSearch DB`; `tandoor`: a `# TODO: <upstream PR link>` marking a workaround).
  Several still run as root with **no** comment (`dash`, `dash-ser`, `reitti-db`, `reitti-tile-cache`) — don't
  treat "this existing service runs as root" as proof it's necessary.
  If a `user:` override causes startup failures, check whether the image expects `PUID`/`PGID` env vars instead
  (`homarr` has its `user:` commented out for this reason), and check for a `-rootless` image variant, which
  usually removes the problem entirely (`lldap`, `uptime-kuma`: no chown step, so a plain `user:` works and the
  `CHOWN`/`SETGID`/`SETUID` caps can go). Images that hard-code their own user (embedded DBs especially) keep
  that ID — `uptime-kuma`'s embedded MariaDB only runs as the image's `node` user (`1000`).
- **Healthcheck** — a `CMD`/`CMD-SHELL` check appropriate to the service, with `interval`/`retries`/
  `start_period`/`timeout`. This is the intent, not the current reality: `authelia`, `diurnal`, `filebrowser`,
  `homebox`, `jellystat`, `linkwarden`, `netalert`, `ottrbox`, `sportarr`, and `uptime-kuma` have none in
  Compose (some, like `authelia`, inherit a `HEALTHCHECK` baked into the image). A `depends_on` health
  condition on a service with no healthcheck at all will simply never become "healthy" per Compose, so check
  for that combination (`docker image inspect --format '{{json .Config.Healthcheck}}' <image>`) before
  assuming a new `depends_on` will work as written. `lldap` relies on its image-baked check for `authelia`'s
  `service_healthy` dependency, so confirm it still exists when bumping that image.

## Container user IDs

Owner decision (2026-11-20): every app gets its **own** UID, the **same on every host**, hard-coded in its
compose file (not `.env`), with no host account behind it. This replaces the shared `PUID_NON_ROOT`, which is
the host login user on Main/SER — so any container escape landed as an account with sudo/docker access, and
every app could read every other app's files. Migration is tracked in `.claude/SECURITY_TODO.md`
("Per-app container UIDs").

Rules:

- **One ID per stack**: an app and its own DB/cache share it (they're one trust unit; the app holds the DB
  credentials anyway). Postgres (`999` today) and Valkey accept any UID, so they follow their app.
- **Image-fixed IDs win** where the image genuinely requires one — document why above `user:`.
- **Shared data** (media libraries, downloads, documents) is reached through one shared **media group, GID
  `3000`**, via `group_add`, with group-writable, setgid directories — never by sharing a UID.
- **Host commands live above the service's `user:` line** (or above the `.env.template` variable they relate
  to, for host-wide setup like the media group) — never in a separate doc. Each block says which host, that it
  runs from the repo root, and when it must be re-run.
- New service: take the next free ID in its range and add it to the list below.

| Range / ID | Assigned to | Status |
|---|---|---|
| `0` | Only where the image needs root, with a reason (`dash`, `dash-ser`: host metrics) | — |
| `1000` | `uptime-kuma` (Oracle) — image-fixed, embedded MariaDB requires it | done |
| **2000–2099** | **Platform** | |
| `2000` | `traefik` + `traefik-provider` (SER), `traefik-oracle` (Oracle) | `traefik`, `traefik-oracle` done |
| `2001` | `authelia`, `authelia-db`, `authelia-cache` | planned |
| `2002` | `lldap`, `lldap-db` | planned |
| `2003` | `autokuma` (Main), `autokuma-ser` (SER) | planned |
| `2004` | `traefik-kop` | planned |
| `2005` | `dozzle` | planned |
| `2006` | `homarr` | needs research (PUID/PGID env, runs as root) |
| `2007` | `apprise` | planned |
| `2008` | `netalert` | needs research (raw-socket caps; may need root) |
| `2009` | `speedtest`, `speedtest-db` | needs research (linuxserver image) |
| `2010` | `watchstate` | planned |
| **2100–2199** | **Household / tools** | |
| `2100` | `tandoor`, `tandoor-db` | needs research (root, upstream TODO) |
| `2101` | `homebox` | planned |
| `2102` | `dailytxt` | needs research (root + chown caps) |
| `2103` | `linkwarden`, `linkwarden-db` | needs research (root) |
| `2104` | `reitti`, `reitti-db`, `reitti-cache`, `reitti-tile-cache` | needs research (root) |
| `2105` | `diurnal`, `diurnal-db` | planned |
| `2106` | `filebrowser` (+ media group for documents) | planned |
| `2107` | `ottrbox` (+ media group if the FTP dir is shared) | planned |
| `2108` | `sonarqube`, `sonarqube-db` — app keeps GID `0` (image requirement) | planned |
| `2109` | `whisper` | planned |
| `2110` | `flaresolverr` | planned |
| **2200–2299** | **Media** (all with `group_add: 3000` where they touch shared data) | |
| `2200` | `qbittorrent` | needs research (linuxserver) |
| `2201`–`2206` | `radarr`, `sonarr`, `lidarr`, `readarr`, `bazarr`, `sportarr` | needs research (linuxserver / PUID env) |
| `2207` | `prowlarr` | needs research (linuxserver) |
| `2208` | `unpackerr` | planned |
| `2209` | `recyclarr` | planned |
| `2210` | `doplarr` | planned |
| `2211` | `emby` | needs research (UID/GID env + chown caps) |
| `2212` | `navidrome` | planned |
| `2213` | `audiobookshelf` | planned |
| `2214` | `tunarr` | needs research (root for MeiliSearch) |
| `2215` | `romm`, `romm-db`, `romm-cache` | planned |
| `2216` | `jellystat`, `jellystat-db` | planned |
| `3000` | Shared **media group** (GID only) | planned |

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

`read_only: true` is used on NetAlertX, LLDAP and Traefik (SER) so far, and works well for any stateless service
(Traefik-kop, Authelia, Dozzle, Apprise, Whisper, FlareSolverr are flagged as easy candidates in
`.claude/SECURITY_TODO.md`). If you're adding a new stateless service, consider setting it there rather than
waiting for a follow-up pass.
