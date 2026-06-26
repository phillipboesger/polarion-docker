# Mailpit + Polarion — minimal reference config

A trimmed, copy-pasteable reference for running Polarion with a [Mailpit](https://github.com/axllent/mailpit) mail catcher, in two shapes:

1. **Compose** — both services in one file (the repo's default shape).
2. **Manual network** — two `docker run` commands on a user-defined network (for non-Compose / single-container workflows).

It uses the same env-var and image conventions as [`docker-compose.yml`](../docker-compose.yml) (`POLARION_IMAGE`, `SMTP_HOST`, `SMTP_PORT`). No machine-specific paths or license files are hard-mounted — see [Licenses](#licenses) below.

> A generic starting point: the Compose shape mirrors the checked-in [`docker-compose.yml`](../docker-compose.yml), and the manual-network shape mirrors a real working `docker run` setup with the machine- and license-specific parts stripped out.

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
  --restart unless-stopped \
  -e MP_SMTP_BIND_ADDR=0.0.0.0:25 \
  -p 25:25 \
  -p 8025:8025 \
  axllent/mailpit:latest

docker run -d --name polarion --network polarion-net \
  --platform linux/amd64 \
  --restart unless-stopped \
  --cpus 4 --memory 4g \
  -p 80:80 -p 5433:5433 -p 5005:5005 \
  -e JAVA_OPTS="-Xmx3g -Xms3g" \
  -e ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0 \
  -e JDWP_ENABLED=true \
  -e SMTP_HOST=mailpit -e SMTP_PORT=25 \
  --health-cmd "wget -q -O /dev/null http://localhost/polarion/" \
  --health-interval 5s --health-timeout 2s \
  --health-retries 10 --health-start-period 10s \
  -v polarion_repo:/opt/polarion/data/svn \
  -v polarion_extensions:/opt/polarion/polarion/extensions \
  ${POLARION_IMAGE:-polarion:local}
```

The Mailpit `-p 25:25` mapping is optional — it only lets the host send to the catcher directly; Polarion reaches it over the `polarion-net` network regardless. See the README "Mail Notifications" section for the full explanation and the `polarionctl.sh start` equivalent (issue #54).

## Licenses

These examples deliberately omit license files, so no per-machine license path ends up in the config. How the license reaches the container depends on **how you start it**:

- **`scripts/polarionctl.sh start`** syncs licenses for you (`polarion_sync_repo_license`): drop `polarion.lic` in `files/` and `avasis.licence` in `data/`, and the start script copies them into `/opt/polarion/polarion/license/` once the container is up.
- **Raw `docker compose up` / `docker run`** (the commands above) do **not** run that sync — the entrypoint only normalizes the license-directory permissions. Supply the license yourself, e.g. `docker cp ./avasis.licence polarion:/opt/polarion/polarion/license/avasis.licence` (or a bind-mount), or use `polarionctl.sh start` instead.

Keep license files out of version control either way.
