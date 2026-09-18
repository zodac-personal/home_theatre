# Deployment topology

Load this when: adding/moving a service between hosts, touching `traefik-kop`/`traefik.yml`'s Redis
provider, or orienting yourself in the repo layout for the first time.

## Three hosts, three compose files

Each root compose file is just an `include:` list of per-service files from `compose/`:

- **`docker-compose.yml`** — the main host (`MAIN_HOST_IP`). Runs most media/app services (the `*arr` suite,
  Emby, Navidrome, AudiobookShelf, RomM, Tandoor, Homebox, ...) plus `traefik-kop`, which registers this
  host's containers into Traefik *without running Traefik itself*.
- **`docker-compose-ser.yml`** — the reverse-proxy host (`REVERSE_PROXY_HOST_IP`). Runs `traefik` and its
  Redis (Valkey) provider, `authelia` + `lldap` (SSO/identity), and LAN-only tooling (Dozzle, Homarr,
  NetAlertX, SpeedTest, Apprise).
- **`docker-compose-oracle.yml`** — a separate, minimal Traefik instance plus Uptime Kuma on an Oracle Cloud
  VPS, deliberately outside the home network. Its purpose: serve `monitor.${DOMAIN_NAME}` as a status page
  that's still reachable if the home internet connection (or the SER host itself) goes down — monitoring
  that lives on the thing being monitored is useless exactly when you need it. It intentionally does **not**
  share the main Traefik's hardening (see `.claude/SECURITY_TODO.md` item 8) — don't assume config parity
  between `docker/traefik/config/traefik.yml` and `docker/traefik/config/traefik-oracle.yml`.

`docker-compose-test.yml` is a deliberate staging area: a place to try out a new service before it earns a
real `compose/*.yml` entry and gets folded into version control. Gitignored, not part of the deployed
topology — if you find something there, it's an in-progress experiment, not dead code.

## How cross-host routing works

One Traefik instance (on the SER host) serves routes for containers running on a *different* host (Main).
The mechanism:

1. `traefik-kop` runs on the Main host, reads that host's container labels locally (needs the Docker socket),
   and writes routing config to Redis.
2. `traefik`'s Redis (Valkey) provider, on the SER host, reads that config and merges it with the routes from
   containers on its own host.

`compose/traefik.yml`'s `traefik-provider` service is that Redis instance — bound to `REVERSE_PROXY_HOST_IP`
(not `0.0.0.0`) with `requirepass` set, because `traefik-kop` on Main needs to reach it over the LAN.
`compose/traefik-kop.yml` is the client side: `BIND_IP` is the Main host's own IP, `REDIS_ADDR` points back at
SER.

Practical implication: when adding a labelled service to `docker-compose.yml` (Main host), nothing extra is
needed for Traefik to pick it up — but the routing decision, TLS termination, and Authelia forward-auth all
happen on a host the container itself never runs on. If a router isn't showing up, check `traefik-kop`'s
health/logs on Main before assuming the label is wrong.

## Repo layout

- `compose/<service>.yml` — one file per service (or tightly-coupled group, e.g. `servarr.yml` bundles the
  `*arr` apps). Included by exactly one of the three root compose files.
- `docker/<service>/config/` — static config mounted read-only into containers (Traefik dynamic configs,
  Authelia's `configuration.yml`, NetAlertX config, etc).
- `storage/` — bind-mounted, per-service persistent data (`../storage/<service>/...` from each compose file).
  Gitignored; never commit it or treat it as source. `-db`/`-cache` suffixed dirs back internal-network-only
  services.
- `.env` (gitignored) / `.env.template` (tracked) — see `secrets-and-env.md`.
- `doc/` — architecture diagram (`home_theatre.drawio`/`.png`) and CI lint configs.
- `.claude/` — AI-facing material: `CLAUDE.md` (index), `reference/` (this directory), `SECURITY_TODO.md`
  (live security backlog).
- `sandbox/` (repo root, not under `.claude/`) — a disposable Docker sandbox for running Claude Code itself
  against this repo with `--dangerously-skip-permissions`. It's tooling for working on the repo, not part of
  the deployed stack; see `sandbox/README.md`.

For the actual service catalogue, auth-integration matrix (which services use OIDC vs basic-auth vs no
internal auth), and backup/DB-upgrade runbooks, see `README.md` — this doc is about structure, not the
service list.
