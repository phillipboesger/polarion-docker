---
paths:
  - ".github/**"
  - "scripts/check-version-branch-drift.sh"
  - "Dockerfile"
  - "CHANGELOG.md"
---
# Version branches, image tags, CI

**Version model.** One branch per Polarion version (`v2410`, `v2506`, `v2512`, `v2606`, plus `main` = newest), named exactly `v` + 4 digits; that branch decides which installer ZIP is built and how the image is tagged. Working branches must not start with `v` (a `v*` branch triggers the heavy build workflow and pushes to GHCR); use `feat/`, `fix/`, `sync/`. PRs only run `pr-checks.yml`. Each version branch is `main` plus the differences listed in its `.github/version-branch-overrides` (e.g. JDK 17 on `v2410`/`v2506`); everything else must match `main`. Sync by merging `main` into a `sync/vNNNN-<date>` branch and opening a PR into `vNNNN`, not by cherry-picking single PRs: narrow ports left the branches months behind once (timezone feature missing, 2026-10). `.github/workflows/version-branch-drift.yml` (`scripts/check-version-branch-drift.sh`) fails when a branch misses `main` changes older than 14 days; each branch's own CI only tests that branch's copy of the files, so it can't see missing features.

| Branch | Installer archive it builds from | Published image tags |
| :--- | :--- | :--- |
| `v2512` | `PolarionALM_2512.zip` | `v2512`, `polarion-v2512` |
| `main` | newest `PolarionALM_*.zip` in the Drive folder | `main`, `latest` |

- **Only `v[0-9][0-9][0-9][0-9]` branches build.** A working branch like `v2410-sync` starts no run; the trigger used to be a broad `v*`, which silently built the newest installer and published an image tagged after the branch. Name working branches `sync/…` or `feat/…`.
- **A manual run can override the version.** Actions → Run workflow takes an optional `version` input; left empty it uses the branch/tag it was dispatched from.
- **`v<NNNN>` floats.** It re-points to the newest build of that version, like `latest`. Use `--pull=always` if you need the newest at start.
- **Provenance is on the image**: `polarion.version`, `polarion.build` (which exact build is behind the floating tag), `polarion.zip` (the Siemens archive consumed), plus `org.opencontainers.image.revision` / `.created`. Read them with `docker ps --format '{{.Label "polarion.build"}}'`.
- Local builds are tagged `polarion:<NNNN>` (no `v` prefix) plus `polarion:local`, which always points at the most recent local build. Examples write the image as `${POLARION_IMAGE:-polarion:local}` (same variable `docker-compose.yml` and `scripts/polarionctl.sh start` read).
- User-facing version: "Image tags and versions" section of `README.md`.
- CI: pin base images and validate checksums for deterministic builds; offer an alternative Dockerfile path or build arg for CI systems without BuildKit.
