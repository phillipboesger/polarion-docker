# FAQ

Short answers to questions that come up repeatedly. For setup and options see the
[README](../README.md).

## The container clock / Polarion shows UTC instead of my timezone. Why?

A container cannot see the host's timezone unless it is passed in. Without `-e TZ=...` and
without `-v /etc/localtime:/etc/host-localtime:ro`, the image falls back to `Etc/UTC` and logs
`WARNING: no host timezone available ... using Etc/UTC`.

Fix (either is enough, no rebuild needed, recreate the container):

```bash
-e TZ=Europe/Berlin \
# or detect it from the host:
-e TZ="$(readlink /etc/localtime | sed 's#.*zoneinfo/##')" \
-v /etc/localtime:/etc/host-localtime:ro \
```

Why there is no automatic detection for a bare `docker run`:

- Nothing from the host is visible inside a container unless it is passed in explicitly.
- Docker Desktop (macOS/Windows) serves `/etc/localtime` from its Linux VM, which is on UTC, so
  the mount alone is not enough there. `TZ` by name works on every runtime.
- `scripts/polarionctl.sh start` and the README examples detect the zone on the host and pass
  it as `TZ` for you.

Check: `docker logs <container> | grep -i timezone` and `docker exec <container> date`.

## The demo work items show an old "Updated" date right after a fresh build.

The demo data is created by the Polarion installer during the image build, so the date comes
from the (cached) build layer, not from the container start. It is unrelated to the timezone.
A build without cache (`docker build --no-cache` or `docker builder prune -a`) refreshes it.

## What survives `docker rm`?

Only the `svn` and `extensions` directories (the volumes). PostgreSQL index data and
`/opt/polarion/etc` do not, which is why `polarion.properties` is re-applied on every start.

## Where do outgoing mails go?

An embedded Mailpit catches them by default (UI on port 8025). Set `SMTP_HOST` to use a real
server, or `MAILPIT_EMBEDDED=false` to disable it. See the README's mail section.

## Why must the build use `--platform linux/amd64`?

Polarion only ships for amd64. On arm64 hosts (Apple silicon) always pass the flag, for both
`docker build` and `docker run`.
