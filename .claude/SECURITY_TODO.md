# Security Review TODO

Findings from a review of the Traefik and Authelia configuration, and of Docker/self-hosting practice across the
compose stacks. Dated 2026-09-17, against commit `cacb514`. Partially updated 2026-11-20 (LLDAP, Uptime Kuma and
Traefik hardening): items touched since carry their own dates, and untouched items' line references may have drifted.

Baseline is good and is *not* repeated below: every image is pinned, essentially every service has `cap_drop: ALL`,
`no-new-privileges`, pids/memory/cpu limits, log rotation and a tmpfs `/tmp`; DB and cache tiers sit on
`internal: true` networks; TLS is 1.3-only with Cloudflare Authenticated Origin Pulls. What follows are the gaps in
that baseline.

Suggested order: items 1, 2 and 3 first — the first two are unauthenticated admin surfaces reachable from the
internet, and both are a few lines of config.

----

## Critical

### 1. Oracle Traefik exposes an unauthenticated API/dashboard to the internet

- [x] **Accepted risk (owner, 2026-11-19)** — the dashboard stays published on `5555` without auth. Traefik's API is
  read-only (GET endpoints only; `api.debug` is off), so the exposure is information disclosure (routing config,
  container IPs, version) and a direct-to-origin port, not control. Revisit if anything sensitive is routed via
  Oracle. Originally: set `api.insecure: false` and remove the `5555:8080` publish (or bind it to `127.0.0.1`).

`docker/traefik/config/traefik-oracle.yml:41` sets `api.insecure: true`, and `compose/traefik-oracle.yml:40`
publishes `"5555:8080"` on `0.0.0.0` — on a public cloud VM. Anyone who can reach port 5555 gets the dashboard and
`/api/rawdata`, i.e. the full routing config.

The main host already fixed exactly this: `insecure: false` plus an unpublished `traefik` entrypoint reachable only
from the Docker network. The Oracle copy never received the change.

### 2. LLDAP's admin UI is published with no middleware at all

- [ ] Put the `lldap` router behind `authelia-forward-auth@file` with its own group and a matching `access_control`
  rule, or delete the router and reach the UI over the LAN on `${REVERSE_PROXY_HOST_IP}:17170`.

`compose/lldap.yml:50-54` creates a router for `lldap.${DOMAIN_NAME}` to port 17170 with **no `middlewares` label**.
That is the admin console for the user store backing every other service, reachable from the internet with only
LLDAP's own login — no Authelia, no rate limit, no security headers, and no `access_control` rule covering it.

### 3. Everything is single-factor

- [ ] Enable WebAuthn (`WEBAUTHN_DISABLE`) and move the administrative hostnames to `two_factor`: `traefik.`,
  `access.`, `log.`, `file.`, `ftp.`

`compose/authelia.yml:60-61` sets `TOTP_DISABLE: "true"` and `WEBAUTHN_DISABLE: "true"`, and every rule in
`access_control` is `one_factor`. One leaked LDAP password gives an attacker the Traefik dashboard, Dozzle (with
container actions enabled), FileBrowser and the *arr stack. `regulation` (3 tries / 120s, 5-minute ban) slows
guessing but does nothing against credential reuse or phishing.

This is the single highest-value change in the list.

### 4. Containers with direct Docker API access

- [ ] Put **every** remaining Docker API consumer behind a socket proxy — owner decision (2026-11-20): address all
  socket access together rather than per service. Prefer `linuxserver/socket-proxy` (maintained fork of
  `tecnativa/docker-socket-proxy`, same env-var model, supports `read_only`). Current direct consumers:
  - `traefik` (SER) — Docker provider; needs only `CONTAINERS=1` (+ the default `EVENTS`/`VERSION`/`PING`).
  - `traefik-kop` (Main) — same read-only needs as Traefik.
  - `autokuma` (Main) and `autokuma-ser` (SER) — read container labels only; same read-only needs.
  - `dozzle` (SER) — logs need `CONTAINERS=1`; container actions additionally need `POST`/`ALLOW_START`/
    `ALLOW_STOP`/`ALLOW_RESTARTS` while `DOZZLE_ENABLE_ACTIONS` is on (item 7) — give it its own proxy instance
    so the others stay read-only.
  - Dozzle's remote hosts are reached through dockerd's own TLS API on `:2376` (README "Dozzle"), which is the full
    API by design — see the `deploy-docker-certs.sh` item under Low; a proxy on each remote host is the
    equivalent fix there.
- [x] `traefik` (SER, 2026-11-20): no longer root — runs as a dedicated `2000:2000` with `read_only: true`; socket
  access is via `group_add` only. Still root-equivalent through the socket until the proxy above is in place.
- [x] `traefik-oracle` (2026-11-19): socket removed entirely — Docker provider replaced by a file provider
  (`docker/traefik/config/dynamic_configs_oracle/`), and it now runs as a dedicated `2000:2000` instead of the
  host login user's ID.

Each consumer above mounts `${DOCKER_SOCKET}` read-write (a `:ro` bind mount does not restrict the API). Whatever
the container's UID, `cap_drop: ALL` and `no-new-privileges` buy very little next to socket access — anyone
controlling the container can start a privileged container with `/` mounted, i.e. host root.

----

## High

### 5. The Authelia router itself has no middleware chain

- [ ] Add at least `rate-limit@file,secure-headers@file` to the `authelia` router.

`compose/authelia.yml:73-75` defines the `auth.` router with no `middlewares`. The login page, the OIDC
authorize/token endpoints and the reset-password flow get no `rate-limit@file` and no `secure-headers@file` (no
HSTS, no nosniff, no frame options) — on the one hostname where those matter most. Authelia's `regulation` guards
only the login attempt itself, not the token or authorize endpoints.

### 6. qBittorrent is internet-facing on two hostnames with no forward auth

- [ ] Put both routers behind `authelia-forward-auth@file` and add the matching `access_control` rules.

`compose/qbittorrent.yml:44` and `docker/traefik/config/dynamic_configs/service_torrent.yml:11` both route to it via
`no-forward-auth@file`, and there is no `access_control` entry for either. It falls back to qBittorrent's own WebUI
login, which has had repeated auth bypass CVEs and, in the LinuxServer image, a generated default admin password.

The *arr stack already reaches qBittorrent over the Docker network, so neither public router needs to be
unauthenticated.

### 7. Dozzle container actions sit behind one factor

- [ ] Either set `DOZZLE_ENABLE_ACTIONS: "false"` or gate `log.${DOMAIN_NAME}` on `two_factor`.

`compose/dozzle.yml:32` sets `DOZZLE_ENABLE_ACTIONS: "true"`, so `log.${DOMAIN_NAME}` can start, stop and restart
containers across every host in `DOZZLE_REMOTE_HOSTS`. Combined with item 3, that is one password away from a remote
kill switch.

### 8. The Oracle stack has none of the main stack's protections

- [ ] Port `config_tls.yml` and `middleware_secure-headers.yml` (at minimum) to the Oracle deployment.
- [x] `aliasHeadersStrategy: delete` and the encoded backslash/null denial ported to `traefik-oracle.yml` (2026-11-20).
- [ ] Reconsider publishing Uptime Kuma on `0.0.0.0` alongside 443.
- [ ] Load the Cloudflare origin certificate. `compose/traefik-oracle.yml` mounts `cloudflare_origin_cert.pem`/`_key.pem`,
  but nothing in `dynamic_configs_oracle/` references them (no equivalent of `config_certs.yml`), so `monitor.` is
  served with Traefik's self-signed default — it only works because Cloudflare isn't in Full (strict) mode. Copying
  `config_certs.yml` across fixes it; Traefik runs as `2000`, so the key must be readable by that ID first (same
  host step as SER's, documented above `user:` in `compose/traefik.yml`).

`docker/traefik/config/traefik-oracle.yml` now has a file provider, but pointed at its own
`dynamic_configs_oracle/` (only the Uptime Kuma routes so far), so the deployment still gets no
`config_tls.yml` (no TLS 1.3 floor, **no Authenticated Origin Pulls**), no `secure-headers`, no `rate-limit` and no
`strip-auth-headers`. Its one public service, Uptime Kuma, is also published on
`0.0.0.0:${UPTIME_KUMA_PORT}` (`compose/uptime-kuma.yml:39`).

### 9. Full unauthenticated API bypass on the *arr apps

- [ ] Narrow the bypasses to the specific paths external callers actually use, or drop them entirely.

`docker/authelia/config/configuration.yml:243-353` bypasses `^/api.*$` for GET/POST/PUT/DELETE on radarr, sonarr,
lidarr, readarr, bazarr and prowlarr. That is the entire management API — add/remove series, edit download clients,
read config — reduced to "whoever holds the API key". Doplarr, Bazarr, Prowlarr and Recyclarr all reach these over
Docker networks, so the bypass is only needed for genuinely external callers.

Note also that `^/api.*$` is unanchored after `api` and so matches `/apifoo`.

*Update 2026-11-20:* radarr and sonarr no longer have Authelia rules at all — they moved to app-native OIDC
(Radarr 7 / Sonarr 5) behind `no-forward-auth@file`, so their API is gated by the app's API key and the UI by OIDC
(including the LAN port, which previously had no auth). The bypass remains on lidarr, readarr, bazarr, prowlarr and
sportarr.

### 10. Authelia's session store has no password

- [ ] Add `--requirepass` to `authelia-cache`, as `traefik-provider` already has.

`compose/authelia.yml:117` gives `authelia-cache` only `--save 60 1 --loglevel warning`, while `traefik-provider`
got `--requirepass`. It holds every live session token. It is on an `internal: true` network with no host port, so
this is defence-in-depth rather than an open door — but it is a one-line inconsistency.

### 11. Secrets are passed as environment variables

- [ ] Switch Authelia to the `AUTHELIA_*_FILE` variants, fed by `secrets:` or a read-only mount.

`SESSION_SECRET`, `STORAGE_ENCRYPTION_KEY`, `OIDC_HMAC_SECRET`, `BACKEND_PASSWORD`, `ADMIN_PASSWORD` and
`SMTP_APP_PASSWORD` all arrive via `environment:` (`compose/authelia.yml:36-68`), so they are readable from
`docker inspect`, `/proc/<pid>/environ` and any crash dump.

The Traefik redis-password indirection at `compose/traefik.yml:19-24` is the same idea; it just has not reached
Authelia.

### 12. Discord webhook baked into an image layer

- [ ] Render `app.conf` at container start from an environment variable instead of at build time.
- [ ] Remove the `ARG NETALERT_VERSION=latest` default.

`docker/netalert/Dockerfile:6-13` takes `DISCORD_NEW_NETWORK_DEVICE_WEBHOOK_URL` as a build ARG and `sed`s it into
`/tmp/app.conf.new` in a `RUN`. Both the ARG value and the resulting file are permanently recoverable from
`docker history` and the layer contents. The `latest` default on line 1 is harmless today, since compose passes
`26.9.0`, but it is an unpinned default.

----

## Medium / best practice

- [ ] **Per-app container UIDs (owner decision 2026-11-20).** Most services share `PUID_NON_ROOT` — the host login
  user on Main/SER — so an escape lands as a sudo/docker-capable account and every app can read every other app's
  data. Migrate each service to its own ID per "Container user IDs" in `.claude/reference/compose-hardening.md`
  (convention + allocation table). Per service: stop it, re-own its `storage/` dirs, set the hard-coded `user:`,
  drop now-unneeded `PUID`/`PGID` env and `CHOWN`/`SETGID`/`SETUID` caps, start, verify — with the exact host
  commands written above its `user:` line. Phases, lowest risk first:
  - [x] Phase 0 — `traefik` (SER), `traefik-oracle` (2000).
  - [ ] Phase 1 — platform services already non-root: `authelia` stack, `lldap` stack, `traefik-provider`,
    `autokuma`/`autokuma-ser`, `traefik-kop`, `dozzle`, `apprise`, `watchstate`; plus host-setup comments for
    `uptime-kuma` (already on its image-fixed ID).
  - [ ] Phase 2 — household/tools already non-root: `homebox`, `diurnal` stack, `sonarqube` stack, `whisper`,
    `flaresolverr`.
  - [ ] Phase 3 — media group: create GID `3000` on Main and make the shared media/download/document dirs
    group-writable + setgid (host commands above a new `.env.template` variable for it); then the media apps
    already non-root: `navidrome`, `audiobookshelf`, `romm` stack, `jellystat` stack, `unpackerr`, `recyclarr`,
    `doplarr`, `filebrowser`, `ottrbox`.
  - [ ] Phase 4 — images that start as root or take `PUID`/`PGID` env; each needs the same research done for
    `lldap`/`uptime-kuma` (rootless variant? honours `user:`?), and some may legitimately stay root with a
    documented reason: linuxserver images (`qbittorrent`, `radarr`, `sonarr`, `lidarr`, `readarr`, `bazarr`,
    `prowlarr`, `speedtest`), `sportarr`, `emby`, `tunarr`, `tandoor`, `dailytxt`, `linkwarden`, `reitti` stack,
    `homarr`, `netalert`.
  - [ ] Phase 5 — remove `PUID_NON_ROOT`/`PGID_NON_ROOT` from `.env.template` and the docs once nothing uses them.

- [ ] **`diurnal-db` has no `cap_drop: ALL`.** Every other Postgres/PostGIS sidecar in the repo
  (`tandoor-db`, `authelia-db`, `reitti-db`, `jellystat-db`, `linkwarden-db`, `lldap-db`, `romm-db`,
  `sonarqube-db`, `speedtest-db`) drops all capabilities; `compose/diurnal.yml`'s `diurnal-db` is the one
  exception, with no comment explaining why. It's on the `internal: true` `diurnal-internal` network with no
  host port, so this is defence-in-depth rather than an open door — same category as item 10 — but looks like
  an oversight rather than a deliberate choice.
- [ ] **LDAP bind uses the admin account.** `configuration.yml:67` binds as `cn=admin,ou=people,...` with
  `LLDAP_ADMIN_PASSWORD` — full write access to the directory for something that only needs read. LLDAP supports a
  dedicated read-only service account.
- [ ] **NetAlertX data is public.** `configuration.yml:227` bypasses `^/php/server/query_json\.php.*$` for GET,
  which serves the full device inventory (MAC addresses, hostnames, vendors, last-seen) unauthenticated. If that is
  for the Homarr widget, scope it by source IP or move the widget to an authenticated call.
- [ ] **Two regexes do not say what they look like they say.** `configuration.yml:136` is `^/api/logs/status?$` —
  the `?` applies to the `s`, so it also matches `/api/logs/statu`; `^/api/logs/status$` is almost certainly
  intended. And `^/.*\.js$` on Jellystat (`:183`) will bypass any future route that happens to end in `.js`.
- [ ] **`jwks_uri` on every OIDC client points at Authelia's own JWKS.** In a client block that field declares the
  *client's* key set (for `private_key_jwt` or signed request objects), not the provider's. Pointing it at
  `https://auth.<domain>/jwks.json` on all eleven clients is copy-paste — harmless in practice, but it makes the
  config read as if something is configured that is not.
- [ ] **PKCE mostly unset**, and `configuration.yml:642-643` explicitly disables it for Tandoor. All of these are
  confidential clients so it is defence-in-depth, but Homarr already has `require_pkce: 'true'`; extend it to the
  clients whose software supports it.
- [ ] **`read_only: true` appears exactly once**, on `netalert` (`compose/netalert.yml:64`) — which proves the
  pattern works here. (Since added to `lldap` (2026-11-19) and `traefik` on SER (2026-11-20).) The stateless services (traefik, traefik-kop, authelia, dozzle, apprise, whisper,
  flaresolverr) are the easy wins.
- [ ] **Pre-release tags on internet-facing apps**: radarr `7.1.0-nightly`, sonarr `5.0.0-develop` (OIDC only exists
  in Sonarr v5, no stable v5 yet), prowlarr
  `2.6.4-nightly`, readarr `0.4.19-nightly`, lidarr `3.1.5-nightly`, sportarr `4.1.7.810-dev`. Pinned, so
  reproducible — but these are unreviewed builds sitting behind the API bypass in item 9.
- [ ] **DailyTxT runs as root with year-long sessions.** `compose/dailytxt.yml:26-27` uses `PUID_ROOT`/`PGID_ROOT`
  (`0:0`) with `CHOWN`/`SETUID`/`SETGID`, `LOGOUT_AFTER_DAYS: "365"`, and `no-forward-auth@file` with no OIDC
  client — a public journal on app-native auth alone. `speedtest` and `emby` are in the same position.
- [ ] **`deploy-docker-certs.sh:53` binds dockerd to `0.0.0.0:2376`.** mTLS is on, so this is not open, but binding
  to the LAN IP would keep it off any other interface. `StrictHostKeyChecking=accept-new` on line 22 also makes the
  first connection to each host trust-on-first-use.
- [ ] **`.github/workflows/docker.yml:50`** passes `-Dsonar.token=` on the command line, where it lands in process
  args and shell history on the runner. The `SONAR_TOKEN` env var on line 40 is already set and is all the scanner
  needs.
- [x] **`compose/lldap.yml` has no healthcheck** while `compose/authelia.yml:24-25` does
  `depends_on: lldap: condition: service_healthy`. Resolved (2026-11-19): the `-alpine-rootless` image ships a
  `HEALTHCHECK` (`/app/lldap healthcheck`, tests LDAP + GraphQL), which satisfies the `depends_on`
  condition — re-check it's still there on image bumps.
