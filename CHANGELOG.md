# Changelog

Notable changes to this repository, in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
style. Image tags stay as documented in the README's "Image tags and versions" section
(`v<NNNN>` / `latest` are floating; `polarion.build` on the running container identifies the
exact build); this file tracks repository-side changes, not a separate release-numbering scheme.

## [Unreleased]

### Security

- Build no longer disables TLS certificate verification on the JDK/Mailpit downloads;
  `ca-certificates` is installed so `wget` can verify the peer (#85).

### Fixed

- `docker stop`, `scripts/polarionctl.sh stop`/`start`, and Apple `container stop` now all give
  Polarion/Apache/PostgreSQL a real grace period to shut down in order instead of SIGKILLing
  them: compose's `stop_grace_period` raised to 120s, `polarionctl.sh`'s stop path does a real
  `docker stop -t 120`/`container stop --time 120` before its force-remove fallback, and the
  `docker run`/`podman run` examples in the README gained `--stop-timeout 120` (#80).
- `postgresql.conf`'s `listen_addresses` line no longer grows without bound across container
  restarts (#83), covered by a new CI regression test.
- The PostgreSQL `current` symlink (and, for consistency, the JVM `current` symlink) now
  resolve deterministically to the highest installed version instead of an unbounded glob (#89).

### Changed

- Entrypoint scripts now report per-script success/failure instead of failing silently — the
  final startup message reflects any failures instead of unconditionally claiming "ready" —
  and the two `sed`-based scripts guard against a missing target file (#87).
- Dockerfile: the frequently-edited `entrypoint.d/`/`polarion_starter.sh` layer moved below the
  JDK/Mailpit/Polarion install layers so editing a script no longer busts that cache (#79).
- Dockerfile: added a `HEALTHCHECK` so a plain `docker run` (without compose) also reports
  container health; removed a dead post-install `apt-get clean`; `install.expect`'s
  `|| true` made explicit (#89).
- `v2404` declared EOL; tagged `eol/v2404` and removed as an active branch; the README's two
  conflicting "Supported versions" sections consolidated into one (#77).
- New README "Graceful shutdown" section documenting the grace-period requirement across every
  supported runtime (Docker, Podman, Apple `container`, Compose, `polarionctl.sh`).
- CI: added `pr-checks.yml` coverage for the `listen_addresses` idempotency guard (#83) and for
  the SIGTERM shutdown ordering / failure-reporting behavior (#80, #87), both licensed-ZIP-free
  so they run on every PR.
