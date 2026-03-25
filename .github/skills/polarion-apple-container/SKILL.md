---
name: polarion-apple-container
description: "Use when you need to run, build, debug, or redeploy Polarion from this repository with Apple container on Apple silicon Macs, including VS Code tasks, container system start, builder setup, image build, log streaming, and plugin redeploy workflows. NOT for Docker Compose or CI publishing workflows."
---

# Polarion Apple Container Skill

Overview

This skill documents the local Apple `container` workflow for this repository. Use it when running Polarion on Apple silicon Macs with macOS 26 or later, especially when you want to drive the workflow from VS Code tasks instead of Docker commands.

This skill is local-development focused. It does not replace the repository's Docker-first CI and Docker Compose workflows.

When to use

- You want to run Polarion from this repository with Apple `container` instead of Docker.
- You need the exact VS Code tasks for Apple `container` system start, builder start, image build, start/stop, logs, or redeploy.
- You want to redeploy a Polarion plugin into a running Apple `container` instance.
- You are debugging Polarion locally on Apple silicon and need host port `5005` exposed for the existing Java debugger attach configuration.

Do not use

- Docker Compose setup. Apple `container` does not provide a Compose-equivalent workflow in this repository.
- CI publishing or registry release automation. Those remain Docker-based.
- Intel Mac workflows or macOS versions older than 26.

Prerequisites

- Apple silicon Mac.
- macOS 26 or later.
- Apple `container` CLI installed and working.
- Polarion ZIP present in the repository `data/` directory.
- Enough resources for Polarion. Recommended defaults in this repo are 8 CPUs and 16 GiB memory for both builder and runtime.

Quick checks

Verify the runtime is installed:

```bash
container system version --format table
```

Verify the repository tasks exist:

```bash
python3 -m json.tool .vscode/tasks.json >/dev/null
```

Repository entrypoints

- Runtime helper: `scripts/polarion-runtime-lib.sh`
- Runtime controller: `scripts/polarionctl.sh`
- Runtime-aware redeploy: `scripts/redeploy.sh`
- VS Code tasks: `.vscode/tasks.json`
- Debugger attach: `.vscode/launch.json`
- End-user docs: `docs/apple-container.md`

Recommended VS Code task order

1. `Polarion: Apple Container System Start`
2. `Polarion: Apple Container Builder Start`
3. `Polarion: Apple Container Build Image`
4. `Polarion: Apple Container Start`
5. `Debug Polarion Container`
6. `Polarion: Full Redeploy (Apple Container)`
7. `Polarion: Live Logs (Apple Container)` or `Polarion: Live Errors ONLY (Apple Container)`

Equivalent CLI workflow

Start system services:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh system-start
```

Start builder:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh builder-start
```

Build image:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh build-image
```

Start Polarion:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh start
```

Stream logs:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh logs
```

Redeploy plugin into the running Apple `container` instance:

```bash
POLARION_RUNTIME=container bash scripts/redeploy.sh path/to/plugin/file polarion custom container
```

Runtime model and constraints

- The repository currently documents Apple `container` with `--platform linux/amd64 --rosetta`.
- Native `arm64` Polarion validation is still an open item. Do not claim native support unless you have tested it.
- Named volumes are preferred because Apple `container` does not auto-delete anonymous volumes on `--rm`.
- Docker Compose files in this repository remain Docker-only.
- The existing debugger attach configuration still works because the Apple start flow maps host port `5005` to container port `5005`.

Ports and defaults used by this repo

- HTTP: `8080`
- PostgreSQL: `5433`
- JDWP: `5005`
- Container name: `polarion`
- Default image tag: `polarion:local`

Important environment variables

- `POLARION_RUNTIME=container`
- `POLARION_CONTAINER_NAME=polarion`
- `POLARION_EXTENSION_NAME=custom`
- `POLARION_IMAGE=polarion:local`
- `POLARION_HTTP_PORT=8080`
- `POLARION_DB_PORT=5433`
- `POLARION_JDWP_PORT=5005`
- `POLARION_JAVA_OPTS=-Xmx8g -Xms8g`
- `POLARION_PLATFORM=linux/amd64`
- `POLARION_CONTAINER_CPUS=8`
- `POLARION_CONTAINER_MEMORY=16g`
- `POLARION_BUILDER_CPUS=8`
- `POLARION_BUILDER_MEMORY=16g`

Troubleshooting

- `container build` fails on architecture mismatch:
  - Keep `POLARION_PLATFORM=linux/amd64` and use Rosetta.
- Polarion starts too slowly or crashes early:
  - Increase `POLARION_CONTAINER_MEMORY` and `POLARION_BUILDER_MEMORY`.
- VS Code logs task shows nothing:
  - Confirm the container name is `polarion` or override `POLARION_CONTAINER_NAME`.
- Redeploy fails during file copy:
  - Confirm the container is running and that `scripts/redeploy.sh` is invoked with `container` as the runtime.
- Networking behaves unexpectedly:
  - Re-run `container system start` and verify published host ports are free.

Examples of prompts that should trigger this skill

- "Start Polarion with Apple container from VS Code in this repo."
- "Build the Polarion image with Apple container and redeploy my plugin."
- "Use the Apple container tasks for Polarion logs and debugger attach."

Related files

- `docs/apple-container.md`
- `.vscode/tasks.json`
- `scripts/polarionctl.sh`
- `scripts/redeploy.sh`
