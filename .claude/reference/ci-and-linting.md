# CI & linting

Load this when: editing a Dockerfile under `docker/**`, editing `README.md`, or touching the CI workflows
themselves.

Two workflows in `.github/workflows/`, both path-triggered (only run when relevant files change):

- **`docker.yml`** — triggers on changes to `docker/autokuma/**`, `docker/netalert/**` (the repo's two
  custom Dockerfiles), `doc/.hadolint.yaml`, or itself. Runs `hadolint` (config: `doc/.hadolint.yaml`,
  recursive) and feeds the report into a SonarQube scan of `docker/`.
  - `doc/.hadolint.yaml` currently ignores `DL3003`, `DL3008`, `DL3018`, `DL3049` — check that list before
    "fixing" a warning in one of those categories; it may be an intentional suppression.
- **`doc.yml`** — triggers on changes to `README.md`, `doc/.markdownlint.json`, or itself. Runs
  `markdownlint-cli2` against `README.md` with `doc/.markdownlint.json`.
  - Notable non-default rules: ATX-style headings, dash-style bullets, 150-char line length (120 for
    headings, 200 for code blocks, tables exempt), `----` as the thematic-break style, asterisk-style
    emphasis, `<details>`/`<img>`/`<summary>` allowed as raw HTML.

If you're editing README.md by hand, match these rules rather than writing freely and fixing lint failures
afterward — the line-length and heading-style rules in particular are easy to violate accidentally in prose.

Neither workflow currently lints anything under `compose/` — compose file correctness is caught at
`docker compose config`/`up` time, not in CI.
