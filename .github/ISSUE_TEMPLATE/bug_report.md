---
name: Bug report
about: Something in the image, the entrypoint or the helper scripts doesn't work
title: ''
labels: bug
assignees: ''
---

<!--
The four things below are asked for every time. Filling them in up front usually
saves a full round trip.
-->

## Host OS and architecture

<!-- e.g. macOS 15.5 on Apple silicon (arm64), or Ubuntu 24.04 on x86_64.
     The image is linux/amd64 (docker-compose.yml `platform:`), so Apple silicon
     runs it under emulation and behaves differently. -->

## Polarion version / branch

<!-- Which branch did you build from (main, v2410, v2506, v2512, v2606), or which
     published image tag are you running? For a local build, also name the
     PolarionALM_*.zip in data/. -->

## Runtime

<!-- Docker Desktop / Docker Engine / Apple `container`, plus the version
     (`docker version` or `container --version`). -->

## What happened

<!-- What you expected, what you got, and the exact commands you ran. -->

## Logs

<!-- The relevant excerpt from `docker logs polarion` (or
     `docker exec polarion tail -n 200 /opt/polarion/data/logs/main/*.log`).
     Trim it to the part around the failure rather than pasting everything. -->

```
paste here
```
