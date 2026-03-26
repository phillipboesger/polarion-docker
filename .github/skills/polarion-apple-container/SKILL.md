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
- Enough resources for Polarion. Current repo defaults are 8 CPUs, 8 GiB for the builder, 4 GiB for the Polarion runtime, and `-Xmx3g -Xms3g` for the JVM.
- If you use avasis extensions, place `data/avasis.licence` in the repo. The start flow syncs it to `/opt/polarion/polarion/license/avasis.licence`.
- If you use a Polarion core XML license, place `files/polarion.lic` in the repo. The start flow syncs it to `/opt/polarion/polarion/license/polarion.lic`.

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
2. `Polarion: Apple Container Build Image`
3. `Polarion: Apple Container Start`
4. `Debug Polarion Container`
5. `Polarion: Full Redeploy (Apple Container)`
6. `Polarion: Live Logs (Apple Container)` or `Polarion: Live Errors ONLY (Apple Container)`

Notes:

- `Polarion: Apple Container Build Image` starts the builder on demand and stops it again after the build.
- Use `Polarion: Apple Container Builder Start` only if you explicitly want the builder kept alive for manual work.
- Use `Polarion: Apple Container Builder Stop` to force-stop the builder.

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

Stop builder explicitly if needed:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh builder-stop
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
- `POLARION_JAVA_OPTS=-Xmx3g -Xms3g`
- `POLARION_PLATFORM=linux/amd64`
- `POLARION_CONTAINER_CPUS=8`
- `POLARION_CONTAINER_MEMORY=4g`
- `POLARION_BUILDER_CPUS=8`
- `POLARION_BUILDER_MEMORY=8g`
- `POLARION_DATA_DIR=$REPO_ROOT/data`
- `POLARION_FILES_DIR=$REPO_ROOT/files`

Troubleshooting

- `container build` fails on architecture mismatch:
  - Keep `POLARION_PLATFORM=linux/amd64` and use Rosetta.
- Polarion starts too slowly or crashes early:
  - First check that you did not raise `POLARION_JAVA_OPTS` above the available container headroom. `4g` container RAM with `-Xmx4g` is too tight and caused startup failure in this repo.
  - Increase `POLARION_CONTAINER_MEMORY` only if a real workload requires it.
- VS Code logs task shows nothing:
  - Confirm the container name is `polarion` or override `POLARION_CONTAINER_NAME`.
- Redeploy fails during file copy:
  - Confirm the container is running and that `scripts/redeploy.sh` is invoked with `container` as the runtime.
- avasis extensions still report missing or limited licence:
  - Verify that `data/avasis.licence` exists in the repo.
  - Verify that `/opt/polarion/polarion/license/avasis.licence` exists in the running container.
  - If the file is present and the log still says only the free contingent is available, the placement is correct and the licence content itself is the remaining issue.
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
