# Reverse proxy & auth (Traefik + Authelia + LLDAP)

Load this when: exposing a new service through Traefik, changing an existing router/middleware, or editing
`docker/authelia/config/configuration.yml`.

Also read `deployment-topology.md` first if you're not already clear on why Traefik runs on the SER host while
most services run on Main — the label-based config below is attached to containers on Main/SER/Oracle, but
routing decisions and TLS termination happen only on whichever host runs the matching Traefik instance.

## Router labels

Standard shape, on the service's own compose entry:

```yaml
labels:
  traefik.enable: "true"
  traefik.http.routers.<service>.rule: "Host(`<subdomain>.${DOMAIN_NAME}`)"
  traefik.http.routers.<service>.entrypoints: "websecure"
  traefik.http.routers.<service>.tls: "true"
  traefik.http.routers.<service>.middlewares: "<middleware-chain>"
  traefik.http.services.<service>.loadbalancer.server.port: "<container-port>"
```

## Choosing the auth middleware

This only applies on the Main/SER hosts. Oracle's Traefik (`traefik-oracle`) has no Authelia or LLDAP
reachable from it at all — different host, no forward-auth container on its network — so
`authelia-forward-auth@file` isn't an available option there, not merely an unused one. Anything routed
through `traefik-oracle` relies on its own login or is unauthenticated by design; treat adding a new
Oracle-routed service as a case to actually discuss, not to default into `no-forward-auth@file`.

For Main/SER, match README's auth-integration matrix (Basic Auth / OIDC / No Internal Auth) for the service
in question — but note the matrix reflects a point-in-time snapshot of a repo with several open `TODO:`
markers in `README.md` itself (e.g. the Basic Auth section), so cross-check against the actual compose file
and `configuration.yml` rather than trusting the README table alone for a service you haven't touched before:

- **`authelia-forward-auth@file`** — the service has no login of its own (or none that should be trusted
  alone); Authelia is the only gate. Use for admin-only surfaces (Traefik dashboard, Dozzle, the *arr admin
  UIs where nothing else guards them).
- **`no-forward-auth@file`** — the service has its own credible login (OIDC via Authelia, or basic auth
  forwarded from the IdP) and doesn't need a second forward-auth hop in front of it.
- Every router should have *one* of these. A router with neither is a gap — see
  `.claude/SECURITY_TODO.md` #2 (LLDAP's admin UI) for what that looks like in practice, and #5/#6 for routers
  that picked `no-forward-auth@file` without actually having a login worth trusting.

Add `rate-limit@file,secure-headers@file` to the middleware chain for anything handling credentials or
sensitive admin actions (login pages, token endpoints) — see `.claude/SECURITY_TODO.md` #5 for a router that's
missing this.

## `access_control` rules

`docker/authelia/config/configuration.yml` has `default_policy: 'deny'` — an unlisted hostname is
unreachable, not merely unauthenticated. Adding a new Authelia-gated router means adding a matching rule
block, following the existing per-service pattern:

```yaml
- domain: '<subdomain>.{{ env "DOMAIN_NAME" }}'
  resources:
    - '^/favicon\.ico$'
    - '^/health'          # whatever unauthenticated paths the client/health-check genuinely needs
  policy: 'bypass'
  methods:
    - 'GET'
- domain: '<subdomain>.{{ env "DOMAIN_NAME" }}'
  policy: 'one_factor'    # or 'two_factor' for admin-sensitive hosts
  subject:
    - [ "group:<service>_admins" ]
```

Notes from past review findings, worth checking against when writing a new rule:

- Anchor regexes precisely. `^/api.*$` matches `/apifoo`, not just `/api/...` — prefer `^/api/(.*)$` or
  similar. `^/api/logs/status?$` makes the `?` apply to the `s`, matching `/api/logs/statu` too, when
  `^/api/logs/status$` was almost certainly intended.
- `bypass` should cover only paths a genuinely external, unauthenticated caller needs (health checks, public
  webhooks). Services reachable from other containers over the Docker network don't need their API
  bypassed for that — see `.claude/SECURITY_TODO.md` #9 for the *arr apps' overly broad `^/api.*$` bypass.
- Prefer `two_factor` over `one_factor` for hostnames whose compromise is high-value (`traefik.`, `access.`,
  `log.`, `file.`, `ftp.`) — see `.claude/SECURITY_TODO.md` #3; single-factor is the current repo-wide state,
  not a target to preserve.
- Use a dedicated LDAP group per service (`<service>_admins`) rather than reusing an existing group, matching
  the existing one-group-per-service convention.

## Monitoring labels

Add Uptime Kuma labels so `autokuma` picks the service up automatically:

```yaml
kuma.<service>.http.name: "<Human Readable Name>"
kuma.<service>.http.url: "${<SERVICE>_MONITOR_URL:?[<service>] Monitor URL missing}"
```

The URL itself is a required env var (see `secrets-and-env.md` for the `${VAR:?...}` pattern) — add it to
`.env.template`.
