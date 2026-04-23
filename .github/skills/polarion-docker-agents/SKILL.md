---
name: polarion-docker-agents
description: "Skill to run and use the Polarion Docker image for automation agents (Playwright, headless captures, MCP testing). Use when you need a reproducible local Polarion instance for agent development, screenshot capture, or integration testing. NOT for production deployment or license redistribution."
---

# Polarion Docker — Agents Skill

Overview

This skill documents a focused, reproducible workflow for building, running, and using the Polarion Docker image when developing automation agents (Playwright, headless screenshot capture, scripted integrations, MCP testing). It emphasizes reproducible builds, required mounts, BuildKit notes, networking for multi-container agent runs, and safe handling of credentials.

When to use

- You need a local Polarion instance for agent development or plugin testing.
- You must capture screenshots or automated UI flows against Polarion (Playwright/Headless Chrome).
- You want a repeatable build + run workflow for CI-like integration tests.

Prerequisites

- Docker (desktop or engine) installed and running.
- Docker BuildKit available (recommended for `RUN --mount=type=bind` in the Dockerfile).
- The Polarion ZIP placed in the repository `data/` directory (e.g. `data/PolarionALM_*.zip`).
- If you use avasis extensions, place `data/avasis.licence` in the repo. The runtime start flow syncs it to `/opt/polarion/polarion/license/avasis.licence`.
- If you use a Polarion core XML license, place `files/polarion.lic` in the repo. The runtime start flow syncs it to `/opt/polarion/polarion/license/polarion.lic`.
- Sufficient disk space and memory for the Polarion image. Current repo defaults cap the runtime container at `4g` and the JVM at `-Xmx3g -Xms3g`.

Quick start (build + run)

Note: The Dockerfile in this repo uses a BuildKit `RUN --mount=type=bind,...` for the Polarion ZIP. Build with BuildKit enabled or adapt the Dockerfile.

Build (recommended with BuildKit):

```bash
# from repo root
DOCKER_BUILDKIT=1 docker build --progress=plain -t polarion:local -f Dockerfile .
```

Run (example):

```bash
# mount local data, expose host port 8080 -> container 80
docker run --rm -it \
  -p 8080:80 \
  --memory 4g \
  -v "$PWD/data":/data:ro \
  -e JAVA_OPTS="-Xmx3g -Xms3g" \
  -e JDWP_ENABLED=false \
  --name polarion-dev \
  polarion:local
```

- Access UI at http://localhost:8080/ after the container finishes startup.
- If you map to port 80 on host, adjust accordingly.

BuildKit note and alternatives

- The existing Dockerfile uses `RUN --mount=type=bind,source=./data/,target=/data/` which requires BuildKit. If you cannot use BuildKit, replace that step with a `COPY` (less efficient) or run a two-step build where the ZIP is `COPY`ed into the image during build.
- Example (non-BuildKit) alternative in Dockerfile:

```dockerfile
COPY data/ /tmp/data/
RUN unzip -q "/tmp/data/PolarionALM_...zip" && ...
```

Agent development flows (recommended)

1. Build the image (see above).
2. Start the container with `-v "$PWD/data":/data:ro` and appropriate env vars.
3. Wait until Polarion HTTP endpoint is available (check `curl -sS http://localhost:8080/` or `docker logs` for startup completion).
4. For Playwright-based scripts: ALWAYS login first using your login script (for example `node login.js`) before running page-capture scripts (this repo's `capture-pages.js` invocation pattern). This avoids session expiration and missing assets.
5. If the automation agent runs in a separate container, create a user network:

```bash
docker network create polarion-net
docker run --rm -d --network polarion-net --name polarion-dev -p 8080:80 -v "$PWD/data":/data:ro polarion:local
# run agent container on same network so it resolves polarion-dev by name
docker run --rm --network polarion-net my-agent-image:latest node run-capture.js --host http://polarion-dev
```

Logs and live debugging

- Tail the most recent log inside the running container:

```bash
docker exec -it polarion-dev sh -c "tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n1)"
```

- The repository includes VS Code tasks for live logs. Use them or use `docker logs -f polarion-dev`.

Security and reproducibility notes

- Do NOT enable JDWP (remote debug) in production images. This repo's Dockerfile exposes `ENV JDWP_ENABLED` — default to `false` for shared images.
- Verify downloaded JDKs and large external archives with SHA256 checksums. Avoid `--no-check-certificate` in production builds. Add `ARG JDK_SHA256` to the Dockerfile and validate with `sha256sum -c`.
- Avoid committing credentials. Use local `.env` files (gitignored) and mount or pass secrets at runtime.

Troubleshooting checklist

- Check that `data/` contains exactly one Polarion ZIP (or adjust the Dockerfile unzip step to select the right file).
- Check that `data/avasis.licence` is present if avasis extensions should be licensed.
- Do not replace `polarion.lic` with `avasis.licence`. They are different files with different target paths.
- If image build fails during JDK download: verify network access, certificate store (`apt-get install -y ca-certificates`), and prefer mirrored/official Temurin assets.
- If the `RUN --mount=type=bind` step fails: ensure `DOCKER_BUILDKIT=1` when building.
- If the service does not start: inspect logs (see "Logs and live debugging").
- If the service is memory-killed early: do not set `-Xmx` equal to the full container limit. This repo needed `-Xmx3g -Xms3g` inside a `4g` container to leave native memory headroom.

Prompts and examples to try in chat

- "Use the Polarion Docker skill to build and run a local instance for Playwright capture."
- "What's the recommended docker run command to expose Polarion on port 8080 and mount data read-only?"

Where this skill lives

- Created in `.github/skills/polarion-docker-agents/SKILL.md`.

Feedback and extension points

- Add example `docker-compose` files for multi-container agent runs.
- Add a minimal `Dockerfile` variant that avoids BuildKit for CI systems that do not support it.
- Add a non-root runtime user example and `tini` usage for proper PID 1 signal handling.

---
