# Mailpit + Polarion — minimal reference config

A trimmed, copy-pasteable reference for running Polarion with a [Mailpit](https://github.com/axllent/mailpit) mail catcher, in two shapes:

1. **Compose** — both services in one file (the repo's default shape).
2. **Manual network** — two `docker run` commands on a user-defined network (for non-Compose / single-container workflows).

It uses the same env-var and image conventions as [`docker-compose.yml`](../docker-compose.yml) (`POLARION_IMAGE`, `SMTP_HOST`, `SMTP_PORT`). No machine-specific paths or license files are hard-mounted — see [Licenses](#licenses) below.

> This is a generic starting point derived from the checked-in Compose file. It will be refined with a concrete working setup (tracked in issue #55).

## Option 1 — Compose

```yaml
services:
  polarion:
    image: ${POLARION_IMAGE:-polarion:local}
    platform: linux/amd64          # required on Apple Silicon
    container_name: polarion
    mem_limit: 4g
    ports:
      - "80:80"                    # HTTP
      - "5433:5433"                # PostgreSQL
      - "5005:5005"                # JDWP debug
    environment:
      - JAVA_OPTS=-Xmx3g -Xms3g
      - SMTP_HOST=mailpit          # route notifications to the catcher below
      - SMTP_PORT=25
    depends_on:
      - mailpit
    restart: unless-stopped

  mailpit:
    image: axllent/mailpit:latest
    container_name: mailpit
    environment:
      - MP_SMTP_BIND_ADDR=0.0.0.0:25   # listen for SMTP on the standard port
    ports:
      - "8025:8025"                # Mailpit web UI -> http://localhost:8025
    restart: unless-stopped
```

```bash
docker compose up -d
# open http://localhost:8025 to read captured mail
```

Both services share Compose's implicit user-defined network, so Polarion resolves `mailpit` as a hostname and the entrypoint writes `announcer.smtp.host=mailpit`.

## Option 2 — Manual network (no Compose)

```bash
docker network create polarion-net

docker run -d --name mailpit --network polarion-net \
  -e MP_SMTP_BIND_ADDR=0.0.0.0:25 \
  -p 8025:8025 \
  axllent/mailpit:latest

docker run -d --name polarion --network polarion-net \
  --platform linux/amd64 \
  -p 80:80 -p 5433:5433 -p 5005:5005 \
  -e SMTP_HOST=mailpit -e SMTP_PORT=25 \
  -v polarion_repo:/opt/polarion/data/svn \
  -v polarion_extensions:/opt/polarion/polarion/extensions \
  ${POLARION_IMAGE:-polarion:local}
```

See the README "Mail Notifications" section for the full explanation and the `polarionctl.sh start` equivalent (issue #54).

## Licenses

Do **not** bind-mount license files in these examples. This repo syncs licenses on startup instead:

- Polarion core XML license: place `polarion.lic` in `files/` → synced to `/opt/polarion/polarion/license/polarion.lic`.
- Avasis extension license: place `avasis.licence` in `data/` → synced to `/opt/polarion/polarion/license/avasis.licence`.

Both are handled by the start scripts (`polarion_sync_repo_license`), so no per-machine license path appears in the Compose/run config. Keep license files out of version control.
