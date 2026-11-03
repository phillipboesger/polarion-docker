# Automation agents against the Polarion image

How to run the image for automation agents (Playwright-based UI captures, headless screenshots, MCP tests, scripted integrations). Operational skill: `.github/skills/polarion-docker-agents/SKILL.md`.

## Build and run

```bash
# from repo root (BuildKit recommended)
DOCKER_BUILDKIT=1 docker build --progress=plain -t "${POLARION_IMAGE:-polarion:local}" -f Dockerfile .

# mount data/, expose host port 8080
docker run --rm -it \
  -p 8080:80 \
  -v "$PWD/data":/data:ro \
  -e JDWP_ENABLED=false \
  --name polarion-dev \
  "${POLARION_IMAGE:-polarion:local}"
```

UI at `http://localhost:8080/` after startup completes. Branch/tag model: "Image tags and versions" in [README.md](../README.md).

## Playwright and automation

- Use the CLI wrapper when available: `export PWCLI="${PWCLI:-./scripts/playwright_cli.sh}"`.
- Always login before running capture scripts:

```bash
# 1) ensure Polarion is up and reachable
# 2) run login script (creates session cookie)
node login.js
# 3) run capture pages
node capture-pages.js
```

- Snapshot frequently when using the CLI to keep element refs stable. Save artifacts under `output/playwright/` (screenshots, traces, PDFs).
- Prefer CLI-first workflows for quick iteration; use `playwright-interactive` only when session persistence is required.

## Development flow

1. Build the image locally.
2. Start the container with `-v "$PWD/data":/data:ro` and the needed env vars.
3. Wait for the endpoint (`curl -sS http://localhost:8080/`).
4. Run `node login.js` (or equivalent) to create a session.
5. Run capture/test scripts. For an agent in a second container, use a network:

```bash
docker network create polarion-net
docker run -d --network polarion-net --name polarion-dev -p 8080:80 -v "$PWD/data":/data:ro "${POLARION_IMAGE:-polarion:local}"
docker run --rm --network polarion-net my-agent-image:latest node run-capture.js --host http://polarion-dev
```

## Logs and debugging

```bash
docker exec -it polarion-dev sh -c "tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n1)"
```

Or `docker logs -f polarion-dev`. The repository includes VS Code tasks for live logs.

## Layout

- `data/`: Polarion ZIP(s), mounted read-only at runtime.
- `scripts/`: helper scripts (downloaders, redeploy helpers, wrappers).
- `output/playwright/`: Playwright artifacts.

## Troubleshooting

- Build fails on `RUN --mount`: enable BuildKit (`DOCKER_BUILDKIT=1`).
- Missing Polarion ZIP: `data/` must contain the expected `PolarionALM_*.zip`.
- Service not starting: inspect logs as above; check memory/disk.
- Captures missing assets or failing: make sure the login step ran and the session cookie is valid.
