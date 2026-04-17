# Agents — repository guide

This repository contains a reproducible Polarion Docker image and helper scripts used for developing and running automation agents (Playwright-based UI captures, headless screenshots, MCP tests, and other scripted integrations). This document collects recommended workflows, conventions, and troubleshooting tips so contributors can get started quickly and consistently.

## Quickstart — build & run

- Build (recommended with BuildKit):

```bash
# from repo root
DOCKER_BUILDKIT=1 docker build --progress=plain -t polarion:local -f Dockerfile .
```

- Run example (mount `data/`, expose host port 8080):

```bash
docker run --rm -it \
  -p 8080:80 \
  -v "$PWD/data":/data:ro \
  -e JDWP_ENABLED=false \
  --name polarion-dev \
  polarion:local
```

- Access UI at `http://localhost:8080/` after startup completes.

## Playwright & automation guidance

- Use the CLI wrapper (`PWCLI`) when available. Set it once:

```bash
export PWCLI="${PWCLI:-./scripts/playwright_cli.sh}"
```

- Always login before running capture scripts. Example pattern:

```bash
# 1) ensure Polarion is up and reachable
# 2) run login script (creates session cookie)
node login.js
# 3) run capture pages
node capture-pages.js
```

- Snapshot frequently when using the CLI to keep element refs stable. Save artifacts under `output/playwright/`.

- Prefer CLI-first workflows (wrapper commands) for quick iteration; use `playwright-interactive` only when session persistence is required.

## Docker / BuildKit notes

- This repository's `Dockerfile` uses `RUN --mount=type=bind` for efficient builds — BuildKit is required for that form. If your environment lacks BuildKit, either:
  - enable BuildKit with `DOCKER_BUILDKIT=1`, or
  - edit the Dockerfile to `COPY` the ZIP and `unzip` during build (less efficient).

- Verify large downloads / JDK archives with SHA256 checksums. Prefer using `ARG` for checksum values and validate with `sha256sum -c` in the Dockerfile.

- Keep `JDWP_ENABLED=false` for shared/dev images unless explicit interactive debug is needed.

## Recommended development flow

1. Build the image locally (see Quickstart).
2. Start Polarion container with `-v "$PWD/data":/data:ro` and appropriate env vars.
3. Wait for the HTTP endpoint to be available (`curl -sS http://localhost:8080/`).
4. Run `node login.js` (or equivalent) to create a valid session for captures.
5. Run capture/test scripts. If running agent in a second container, create a Docker network:

```bash
docker network create polarion-net
docker run -d --network polarion-net --name polarion-dev -p 8080:80 -v "$PWD/data":/data:ro polarion:local
docker run --rm --network polarion-net my-agent-image:latest node run-capture.js --host http://polarion-dev
```

## Logs & debugging

- Tail the most recent Polarion log inside a running container:

```bash
docker exec -it polarion-dev sh -c "tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n1)"
```

- Or use `docker logs -f polarion-dev` for container stdout/stderr.
- The repository includes VS Code tasks for live logs (see the workspace tasks list).

## Security & secrets

- Never commit credentials or license files. Use a gitignored `.env` for local env vars, or mount secrets at runtime.
- Validate third-party downloads (JDK, archives) via checksums; avoid `--no-check-certificate` in production builds.

## Conventions & repository layout

- `Dockerfile` — image build (see root Dockerfile).
- `data/` — place Polarion ZIP(s) here (mounted read-only into container at runtime).
- `scripts/` — helper scripts (playwright wrappers, downloaders, redeploy helpers).
- `output/playwright/` — recommended path for Playwright artifacts (screenshots, traces, PDFs).

Suggested agent folder layout (optional):

```
agents/
  playwright/
    login.js
    capture-pages.js
    Dockerfile (if containerized)

scripts/
  playwright_cli.sh
```

## CI / reproducibility tips

- Provide an alternative Dockerfile path or build argument for CI systems that do not support BuildKit.
- Pin base images and validate checksums to make builds deterministic.

## Troubleshooting checklist

- Build fails on `RUN --mount` — enable BuildKit (`DOCKER_BUILDKIT=1`).
- Missing Polarion ZIP — ensure `data/` contains the expected `PolarionALM_*.zip`.
- Service not starting — inspect logs as shown above; check memory/disk.
- Playwright captures missing assets or failing — ensure login step runs and session cookie is valid.

## Examples & useful commands

- Build with BuildKit:

```bash
DOCKER_BUILDKIT=1 docker build -t polarion:local -f Dockerfile .
```

- Run Polarion locally:

```bash
docker run --rm -it -p 8080:80 -v "$PWD/data":/data:ro --name polarion-dev polarion:local
```

- Create a dev network and run agent container on same network:

```bash
docker network create polarion-net
docker run -d --network polarion-net --name polarion-dev -p 8080:80 -v "$PWD/data":/data:ro polarion:local
docker run --rm --network polarion-net my-agent-image node run-capture.js --host http://polarion-dev
```

## Where to look next

- `Dockerfile` (root) — image build details.
- `scripts/` — helper scripts; add a `playwright_cli.sh` if not present.
- `.github/skills/polarion-docker-agents/SKILL.md` — operational guidance used to build this document.

If you'd like, I can also:

- Add a `scripts/playwright_cli.sh` wrapper and `agents/playwright` example folder,
- Add a `docker-compose.agent.yml` example for multi-container local testing.

---

Generated with guidance from repository skills and Playwright CLI best practices.
