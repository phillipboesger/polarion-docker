---
paths:
  - "Dockerfile"
  - ".gitattributes"
  - "scripts/**"
  - "entrypoint.d/**"
  - "polarion_starter.sh"
---
# Dockerfile and script gotchas

- Shell content needed by the image goes in a file under `scripts/`/`entrypoint.d/` and is `COPY`'d, never quoted inline in a `RUN`. Every COPY'd script is paired with `.gitattributes` LF handling plus `sed -i 's/\r//'` in the Dockerfile.
- hadolint runs at `failure-threshold: error`, but avoid warnings too: no pipes in `RUN` (DL4006) and use documented inline `# hadolint ignore=` only where unavoidable.
- The image intentionally runs as root (Apache/SVN/service permissions depend on it).
- The `Dockerfile` uses `RUN --mount=type=bind`, so BuildKit is required (`DOCKER_BUILDKIT=1`). Without BuildKit the only alternative is editing the Dockerfile to `COPY` the ZIP and `unzip` during build (less efficient).
- Verify large downloads / JDK archives with SHA256 checksums: use `ARG` for checksum values and validate with `sha256sum -c` in the Dockerfile. Avoid `--no-check-certificate` in production builds.
- Never run `polarionctl.sh start/stop/build-image` for real from tests; mock the container CLI.
