# polarion-docker

Self-configuring Docker image around the proprietary Siemens Polarion ALM installer (BYO installer ZIP + license). No application code: the "source" is the `Dockerfile`, the shell scripts run at container start (`entrypoint.d/`), and CI.

## Commands

```bash
# Build (BuildKit required; Polarion ZIP in data/, gitignored). Always --platform linux/amd64 (Polarion ships amd64 only, host is often arm64)
DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --progress=plain \
  --build-arg POLARION_ZIP=PolarionALM_2512.zip -t polarion:local -f Dockerfile .
# Build/run/stop via the runtime-agnostic wrapper (Docker or Apple `container`)
bash scripts/polarionctl.sh {list-zips|build-image|list-images|start|stop|logs|errors}
# Lint, same tools and flags as CI (.github/workflows/pr-checks.yml)
docker run --rm -i hadolint/hadolint hadolint --failure-threshold error --ignore DL3008 --ignore DL3009 --ignore DL3015 - < Dockerfile
shellcheck --shell=bash --exclude=SC1091,SC2039 -S error entrypoint.d/*.sh scripts/*.sh polarion_starter.sh
yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" .github/workflows/ docker-compose.yml docker-compose.dev.yml
python3 -m py_compile scripts/download_polarion_zip.py
docker compose -f docker-compose.yml config --quiet   # and docker-compose.dev.yml
```

## Tests

- No local test runner. Tests are inline shell steps in CI jobs (`timezone-tests`, `shutdown-tests` in `pr-checks.yml`; real-image smoke tests in `build-and-push.yml`). They build small standalone images with only the layers under test, so no licensed ZIP is needed. To run one locally, copy that step's `run:` block.
- New behaviour needs an automated CI test plus doc updates (README, CHANGELOG), not just manual verification.
- Never run `polarionctl.sh start/stop/build-image` for real from tests; mock the container CLI.

## Hard constraints

- The image intentionally runs as root (Apache/SVN/service permissions depend on it).
- `base.url` must stay `http://localhost` by default (maintainer decision); any base-URL fix is an opt-in override, not a changed default.
- Working branches must not start with `v` (a `v*` branch triggers the heavy build and pushes to GHCR); use `feat/`, `fix/`, `sync/`.
- Never commit credentials or license files; use a gitignored `.env` or runtime mounts.
- Keep `JDWP_ENABLED=false` for shared/dev images unless interactive debugging is needed.

## Docs

- User docs: `README.md`, `CHANGELOG.md`, `PLUGIN-DEVELOPMENT.md`, `docs/apple-container.md`, `docs/FAQ.md`.
- Automation agents (Playwright captures, dev flow, logs, troubleshooting): `docs/agent-automation.md`; skill `.github/skills/polarion-docker-agents/SKILL.md`.
- Path-scoped rules in `.claude/rules/`: `startup-chain.md` (entrypoint.d, polarion_starter.sh), `version-branches.md` (branch/tag model, CI), `dockerfile.md` (Dockerfile, scripts, compose).
