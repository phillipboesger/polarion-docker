# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This repo builds a self-configuring Docker image around the proprietary Siemens Polarion ALM installer (BYO installer ZIP + license). There is no application code: the "source" is the `Dockerfile`, the shell scripts run at container start, and CI. `AGENTS.md` and `README.md` hold the user-facing workflows (Playwright captures, run examples, env vars); don't duplicate them here.

## Commands

```bash
# Build (needs BuildKit for RUN --mount; a Polarion ZIP must be in data/, gitignored)
DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --progress=plain \
  --build-arg POLARION_ZIP=PolarionALM_2512.zip -t polarion:local -f Dockerfile .

# Build/run/stop via the runtime-agnostic wrapper (Docker or Apple `container`)
bash scripts/polarionctl.sh {list-zips|build-image|list-images|start|stop|logs|errors}

# Lint, same tools and flags as CI (.github/workflows/pr-checks.yml)
docker run --rm -i hadolint/hadolint hadolint --failure-threshold error --ignore DL3008 --ignore DL3009 --ignore DL3015 - < Dockerfile
shellcheck --shell=bash --exclude=SC1091,SC2039 -S error entrypoint.d/*.sh scripts/*.sh polarion_starter.sh
yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" .github/workflows/ docker-compose.yml docker-compose.dev.yml
python3 -m py_compile scripts/download_polarion_zip.py
docker compose -f docker-compose.yml config --quiet   # and docker-compose.dev.yml
```

- The host is often arm64 but Polarion only ships amd64: always pass `--platform linux/amd64`.
- There is no local test runner. Tests live as inline shell steps inside CI jobs (`timezone-tests`, `shutdown-tests` in `pr-checks.yml`; the real-image smoke tests in `build-and-push.yml`). They build small standalone images that replicate only the layers under test, so no licensed ZIP is needed. To run one locally, copy that step's `run:` block.
- New behaviour needs an automated CI test plus doc updates (README, CHANGELOG), not just manual verification.

## Architecture

**Startup chain.** `ENTRYPOINT ./polarion_starter.sh` sources every `entrypoint.d/*.sh` in filename order. Because they are *sourced* into one shell, not executed: they share variables and PIDs, must `return` (not `exit`) to signal failure, and a failing script is logged but does not stop later ones or the container. The numeric prefix is the ordering contract (timezone → postgres config/start → URLs → SVN bootstrap → properties → apache → java → license perms → mailpit → `99` starts Polarion). `polarion_starter.sh` also traps SIGTERM to stop Polarion, Apache, and Postgres in order (compose sets `stop_grace_period: 120s` for this).

**Config is rewritten on every start, not baked in.** `/opt/polarion/etc/polarion.properties` is edited in place by `entrypoint.d/03-configure-urls.sh`, `04-configure-properties.sh` (add-or-update list of properties, driven by env vars such as `ALLOWED_HOSTS`, `SMTP_HOST`, `MAILPIT_EMBEDDED`), and again by `99-start-polarion.sh`, which force-sets `base.url`/`repo`/`controlHostname` to `localhost`. When changing URL/host behaviour, check all three, since a later script silently overrides an earlier one. `base.url` must stay `http://localhost` by default (maintainer decision); any base-URL fix has to be an opt-in override, not a changed default.

**Version model.** One branch per Polarion version (`v2410`, `v2506`, `v2512`, `v2606`, plus `main` = newest), named exactly `v` + 4 digits; that branch decides which installer ZIP is built and how the image is tagged. Working branches must not start with `v` (a `v*` branch triggers the heavy build workflow and pushes to GHCR); use `feat/`, `fix/`, `sync/`. PRs only run `pr-checks.yml`. Version-specific state (e.g. JDK major version) lives per branch, so a change to `main` often needs porting to the version branches; READMEs have diverged, so port by section rather than cherry-pick.

**Persisted state.** Only the `svn` and `extensions` directories survive `docker rm`. Postgres index data and `/opt/polarion/etc` do not, which is why the properties are re-applied at every start.

**Helper scripts** (`scripts/`): `polarion-runtime-lib.sh` abstracts Docker vs Apple `container` and host timezone detection (sourced by `polarionctl.sh`); `redeploy.sh` backs the VS Code tasks (plugin redeploy into a running container); `download_polarion_zip.py` fetches installers.

## Gotchas

- Shell content needed by the image goes in a file under `scripts/`/`entrypoint.d/` and is `COPY`'d, never quoted inline in a `RUN`. Every COPY'd script is paired with `.gitattributes` LF handling plus `sed -i 's/\r//'` in the Dockerfile.
- hadolint runs at `failure-threshold: error`, but avoid warnings too: no pipes in `RUN` (DL4006) and use documented inline `# hadolint ignore=` only where unavoidable.
- The image intentionally runs as root (Apache/SVN/service permissions depend on it).
- Never run `polarionctl.sh start/stop/build-image` for real from tests; mock the container CLI.
