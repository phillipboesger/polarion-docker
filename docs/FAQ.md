# FAQ

Short answers to questions that come up repeatedly. For setup and options see
the [README](../README.md).

- [Build and pull](#build-and-pull)
- [Start and access](#start-and-access)
- [Data and shutdown](#data-and-shutdown)
- [Timezone](#timezone)

## Build and pull

### Where do I get the Polarion installer, and where does it go?

Download the Linux ZIP (e.g. `PolarionALM_2512.zip`) from Siemens and put it in
`data/`. With one `polarion*.zip` present the build picks it up. With several,
select one:

```bash
docker build --platform linux/amd64 \
  --build-arg POLARION_ZIP=PolarionALM_2512.zip -t polarion:local .
# or: POLARION_ZIP=PolarionALM_2512.zip bash scripts/polarionctl.sh build-image
```

`bash scripts/polarionctl.sh list-zips` shows the selectable archives. The ZIP
and the licenses are not part of the repository.

### Why must I pass `--platform linux/amd64`?

Polarion only ships for amd64. On arm64 hosts (Apple silicon) pass the flag to
both `docker build` and `docker run`.

### Why does pulling the GHCR image say "denied"?

The pre-built image is access-restricted, it is not public. Ask the repository
owner for access, then log in with a GitHub token that has the `read:packages`
scope (README, "Option B"). Without access, build locally (README, "Option A").

### Which tag or branch do I use?

One branch per Polarion version (`v2410`, `v2506`, `v2512`, `v2606`), `main`
builds the newest. `v<NNNN>` is a floating tag that moves with every build of
that branch. To see which build a container really runs, read its labels:

```bash
docker ps --format '{{.Names}}\t{{.Label "polarion.build"}}'
```

## Start and access

### When is Polarion ready?

The first start takes minutes (longer for a cold `linux/amd64` start on Apple
silicon). The image's health check allows 10 minutes before it counts failures,
so `starting` is normal at first. Follow progress with
`docker logs -f <container>`. Ready means `http://localhost/polarion/` answers
and `docker ps` shows `healthy`.

### What are the login and the license?

The Polarion default user is `admin` / `admin`. Without a `polarion.lic` in
`files/` Polarion uses its own trial or activation flow. With a license file it
is synced into the container on start (README, "Option A", step 3). A SALT
license server is switched on with `SALT_LICENSE_SERVER`.

### Can I reach Polarion under another hostname or port?

Use `http://localhost` on the Docker host. `base.url`, `repo` and
`controlHostname` are set to `localhost` on every start on purpose, so a
different hostname or port can be rejected, and links in mails keep pointing to
`localhost`. If you must use another hostname, add it to `ALLOWED_HOSTS`
(default `localhost,127.0.0.1,0.0.0.0`), which feeds Tomcat's host safe-list:

```bash
-e ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,my-host
```

### How much memory does it need?

The defaults are a `4g` container limit and a `3g` JVM heap
(`JAVA_OPTS="-Xmx3g -Xms3g"`). Keep the container limit about 1 GB above the
heap, so the process has native headroom. If you raise `-Xmx`, raise
`--memory` with it.

### Where do outgoing mails go?

An embedded Mailpit catches them by default (web UI on port 8025). Set
`SMTP_HOST` to use a real server, or `MAILPIT_EMBEDDED=false` to disable it.

### Why do I get "no more credentials" or a 500 with SVN?

Do not point SVN clients at `/repo`. It only knows Polarion's system user.
Use `http://<host>/repo-local` with your Polarion user and password. On 2512+
it answers once Polarion is up (README, "External SVN Endpoints").

## Data and shutdown

### What survives `docker rm`?

Only the `svn` and `extensions` volumes. The PostgreSQL index data and
`/opt/polarion/etc` do not, which is why `polarion.properties` is re-applied
on every start.

### How do I stop the container without damage?

Give it time for the ordered shutdown (Polarion, Apache, PostgreSQL):

```bash
docker run ... --stop-timeout 120 ...
docker stop -t 120 polarion
```

`polarionctl.sh stop` and both compose files already do this. A shorter grace
period kills PostgreSQL mid-write. The next start cleans that up on its own,
but it is avoidable.

## Timezone

### Why does the clock show UTC instead of my timezone?

A container cannot see the host's timezone unless it is passed in. Without
`-e TZ=...` and without `-v /etc/localtime:/etc/host-localtime:ro` the image
falls back to `Etc/UTC` and logs
`WARNING: no host timezone available ... using Etc/UTC`.

Fix (either is enough, no rebuild, recreate the container):

```bash
-e TZ=Europe/Berlin \
# or detect it from the host:
-e TZ="$(readlink /etc/localtime | sed 's#.*zoneinfo/##')" \
-v /etc/localtime:/etc/host-localtime:ro \
```

Why a bare `docker run` cannot detect it:

- Nothing from the host is visible inside a container unless passed in.
- Docker Desktop (macOS/Windows) serves `/etc/localtime` from its Linux VM,
  which is on UTC, so the mount alone is not enough there. `TZ` by name works
  on every runtime.
- `scripts/polarionctl.sh start` and the README examples pass `TZ` for you.

Check with `docker logs <container> | grep -i timezone` and
`docker exec <container> date`.

The demo work items can still show an old "Updated" date after a fresh build.
They are created by the installer during the image build, so the date comes
from the cached layer. It is unrelated to the timezone, and a build without
cache refreshes it.
