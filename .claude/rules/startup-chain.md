---
paths:
  - "entrypoint.d/**"
  - "polarion_starter.sh"
  - "scripts/**"
  - "docker-compose*.yml"
---
# Startup chain and runtime state

**Startup chain.** `ENTRYPOINT ./polarion_starter.sh` sources every `entrypoint.d/*.sh` in filename order. Because they are *sourced* into one shell, not executed: they share variables and PIDs, must `return` (not `exit`) to signal failure, and a failing script is logged but does not stop later ones or the container. The numeric prefix is the ordering contract (timezone → postgres config/start → URLs → SVN bootstrap → properties → apache → java → license perms → mailpit → `99` starts Polarion). `polarion_starter.sh` also traps SIGTERM to stop Polarion, Apache, and Postgres in order (compose sets `stop_grace_period: 120s` for this).

**Config is rewritten on every start, not baked in.** `/opt/polarion/etc/polarion.properties` is edited in place by `entrypoint.d/03-configure-urls.sh`, `04-configure-properties.sh` (add-or-update list of properties, driven by env vars such as `ALLOWED_HOSTS`, `SMTP_HOST`, `MAILPIT_EMBEDDED`), and again by `99-start-polarion.sh`, which force-sets `base.url`/`repo`/`controlHostname` to `localhost`. When changing URL/host behaviour, check all three, since a later script silently overrides an earlier one. `base.url` must stay `http://localhost` by default (maintainer decision); any base-URL fix has to be an opt-in override, not a changed default.

**Persisted state.** Only the `svn` and `extensions` directories survive `docker rm`. Postgres index data and `/opt/polarion/etc` do not, which is why the properties are re-applied at every start.

**Helper scripts** (`scripts/`): `polarion-runtime-lib.sh` abstracts Docker vs Apple `container` and host timezone detection (sourced by `polarionctl.sh`); `redeploy.sh` backs the VS Code tasks (plugin redeploy into a running container); `download_polarion_zip.py` fetches installers.
