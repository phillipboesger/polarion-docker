# Base image for Polarion Docker container
ARG SOURCE_IMAGE=ubuntu:24.04
# SOURCE_IMAGE defaults to the tagged ubuntu:24.04; the ARG is intentionally overridable.
# hadolint ignore=DL3006
FROM $SOURCE_IMAGE

# Polarion installer archive to use, relative to the bind-mounted data/ directory
# (e.g. POLARION_ZIP=PolarionALM_2512.zip). When empty, the build falls back to the
# single-file glob below, preserving the previous behaviour.
ARG POLARION_ZIP=

# Temurin JDK major version to install; the build always fetches the latest GA release for
# this major version via the Adoptium API instead of pinning an exact build.
ARG JDK_MAJOR_VERSION=21

# Mailpit version for the built-in mail catcher (runs by default at runtime; disable
# with MAILPIT_EMBEDDED=false). Defaults to "latest" so each image build picks up the
# newest release; pass --build-arg MAILPIT_VERSION=vX.Y.Z to pin a specific one.
ARG MAILPIT_VERSION=latest

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNLEVEL=1

# Configure apt to be more resilient
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
  echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries && \
  echo 'Acquire::ftp::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries

# Install basic dependencies and setup locale
# tzdata provides /usr/share/zoneinfo so entrypoint.d/00-configure-timezone.sh can resolve an
# explicit TZ override. Installed noninteractively it defaults /etc/localtime to Etc/UTC, the
# fallback used whenever nothing else sets the container clock.
RUN apt-get -y update && \
  apt-get -y install --no-install-recommends sudo unzip expect wget locales libc6 tzdata ca-certificates \
  apache2 subversion libapache2-mod-svn libswt-gtk-4-java apache2-utils libaprutil1-dbd-pgsql \
  postgresql postgresql-client postgresql-contrib util-linux-extra iputils-ping && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Make /etc/localtime a real, freely rewritable file instead of the symlink tzdata installs
# (-> /usr/share/zoneinfo/Etc/UTC) — cp'ing onto a symlinked /etc/localtime would silently
# overwrite that shared Etc/UTC reference file itself instead of /etc/localtime, corrupting
# it for every consumer, including entrypoint.d/00-configure-timezone.sh's own reverse zone
# lookup. That script rewrites both this file and /etc/timezone on every container start
# (some JDKs read /etc/timezone's text content before /etc/localtime; PostgreSQL and Apache
# are started via "service", which drops the TZ env var entirely), so what's baked in here
# only matters if entrypoint.d is ever bypassed — Etc/UTC is a safe default either way.
RUN cp --remove-destination /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
  rm -f /etc/timezone

# Add postgres symlink for genericity.
# Resolved to the highest installed major version rather than globbed: with two versions
# present, `ln -s a b current` would treat `current` as a directory and silently create
# current/a, current/b instead of the symlink everything below (ENV PATH,
# entrypoint.d/02-start-postgres.sh) depends on.
# hadolint ignore=DL4006
RUN set -eux; \
  pg_dir="$(find /usr/lib/postgresql -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"; \
  test -n "${pg_dir}"; \
  ln -s "${pg_dir}" /usr/lib/postgresql/current

# Set locale environment
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup working directory
WORKDIR /polarion_root

# Download and install the latest OpenJDK (Temurin) GA release for JDK_MAJOR_VERSION
# Resolve the correct archive for the image architecture (x86_64 vs aarch64) via the Adoptium API
RUN set -eux; \
  arch="$(uname -m)"; \
  case "$arch" in \
  x86_64|amd64) jdk_arch="x64" ;; \
  aarch64|arm64) jdk_arch="aarch64" ;; \
  *) echo "Unsupported architecture: $arch"; exit 1 ;; \
  esac; \
  wget --progress=dot:giga -O jdk.tar.gz \
  "https://api.adoptium.net/v3/binary/latest/${JDK_MAJOR_VERSION}/ga/linux/${jdk_arch}/jdk/hotspot/normal/eclipse"; \
  mkdir -p /usr/lib/jvm; \
  tar -zxf jdk.tar.gz -C /usr/lib/jvm; \
  rm jdk.tar.gz

# Configure Java alternatives for JDK 21.
# Same deterministic-resolution reasoning as the postgres symlink above: only one JDK is
# ever installed by this build, but resolving by highest version rather than an unbounded
# glob avoids the same directory-instead-of-symlink failure mode if that ever changes.
# hadolint ignore=DL4006
RUN set -eux; \
  jvm_dir="$(find /usr/lib/jvm -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"; \
  test -n "${jvm_dir}"; \
  ln -s "${jvm_dir}" /usr/lib/jvm/current && \
  update-alternatives --install /usr/bin/java java /usr/lib/jvm/current/bin/java 100 && \
  update-alternatives --install /usr/bin/jar jar /usr/lib/jvm/current/bin/jar 100 && \
  update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/current/bin/javac 100 && \
  update-alternatives --set jar /usr/lib/jvm/current/bin/jar && \
  update-alternatives --set javac /usr/lib/jvm/current/bin/javac

# Set Java environment variables
ENV JAVA_HOME="/usr/lib/jvm/current" \
  JDK_HOME="/usr/lib/jvm/current"

# Add Java environment to system environment
RUN echo "JAVA_HOME=\"$JAVA_HOME\"" >> /etc/environment && \
  echo "JDK_HOME=\"$JDK_HOME\"" >> /etc/environment

# Verify Java installation
RUN echo "JAVA_HOME and JDK_HOME have been successfully set to:" && \
  echo "JAVA_HOME=$JAVA_HOME" && \
  echo "JDK_HOME=$JDK_HOME"  && \
  java -version

# Install the Mailpit binary for the built-in mail catcher.
# It runs by default at runtime (entrypoint.d/60-mailpit.sh); disable with MAILPIT_EMBEDDED=false.
# With MAILPIT_VERSION=latest the build resolves the newest release via GitHub's
# "releases/latest/download" redirect; a pinned vX.Y.Z uses the exact release asset.
RUN set -eux; \
  arch="$(uname -m)"; \
  if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then \
  mp_arch="amd64"; \
  elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then \
  mp_arch="arm64"; \
  else \
  echo "Unsupported architecture for Mailpit: $arch"; exit 1; \
  fi; \
  if [ "$MAILPIT_VERSION" = "latest" ]; then \
  mp_url="https://github.com/axllent/mailpit/releases/latest/download/mailpit-linux-${mp_arch}.tar.gz"; \
  else \
  mp_url="https://github.com/axllent/mailpit/releases/download/${MAILPIT_VERSION}/mailpit-linux-${mp_arch}.tar.gz"; \
  fi; \
  wget --progress=dot:giga -O /tmp/mailpit.tar.gz "$mp_url"; \
  tar -xzf /tmp/mailpit.tar.gz -C /usr/local/bin mailpit; \
  rm -f /tmp/mailpit.tar.gz; \
  test -x /usr/local/bin/mailpit

# Copy install.expect to Polarion directory and make both scripts executable
COPY --chmod=755 --chown=0:0 install.expect ./
RUN sed -i 's/\r//' install.expect

# Unzip Polarion and install it.
# The Polarion dir is created by unzip mid-RUN under a transient bind-mount, so WORKDIR cannot target it.
# hadolint ignore=DL3003
RUN --mount=type=bind,source=./data/,target=/data/ \
  set -x && \
  if [ -n "${POLARION_ZIP}" ]; then \
  zip_path="/data/${POLARION_ZIP}"; \
  else \
  set -- /data/[Pp]olarion*.zip; \
  if [ "$#" -gt 1 ]; then \
  echo "ERROR: Multiple polarion*.zip archives in data/; pass --build-arg POLARION_ZIP=<file> to choose one of:" >&2; \
  for candidate in "$@"; do echo "  - $(basename "${candidate}")" >&2; done; \
  exit 1; \
  fi; \
  zip_path="$1"; \
  fi && \
  if [ ! -f "${zip_path}" ]; then \
  echo "ERROR: No Polarion installer ZIP found at ${zip_path}. Add a polarion*.zip (e.g. PolarionALM_2512.zip) to data/ or pass --build-arg POLARION_ZIP=<file>." >&2; \
  exit 1; \
  fi && \
  echo "Installing Polarion from ${zip_path}" && \
  unzip -q "${zip_path}" && \
  cd Polarion && \
  if ! ../install.expect; then echo "install.expect returned non-zero, continuing to verification" >&2; fi && \
  test -d /opt/polarion/polarion && \
  test -d /opt/polarion/data/svn && \
  cd .. && \
  rm -r Polarion && \
  mkdir -p /opt/polarion/bootstrap/svn && \
  cp -a /opt/polarion/data/svn/. /opt/polarion/bootstrap/svn/

# Add PostgreSQL to PATH
ENV PATH="/usr/lib/postgresql/current/bin:${PATH}"

# Set environment variables for debugging support (default: enabled)
ENV JDWP_ENABLED="true"

# Add convenience aliases for interactive root shells (see config/bash_aliases).
# Debian-based images source ~/.bash_aliases from ~/.bashrc already; the explicit
# source keeps the aliases working for a non-Debian SOURCE_IMAGE too.
COPY config/bash_aliases /root/.bash_aliases
RUN sed -i 's/\r//' /root/.bash_aliases && \
  printf '\n. /root/.bash_aliases\n' >> /root/.bashrc

# Copy modular entrypoint scripts.
# Kept last on purpose: these are only read at container start, never at build time, but they
# change far more often than the JDK/Mailpit/Polarion install layers above — copying them
# earlier would bust that cache on every script edit. WORKDIR is still /polarion_root.
COPY entrypoint.d/ /opt/polarion/entrypoint.d/
RUN sed -i 's/\r//' /opt/polarion/entrypoint.d/*.sh && chmod +x /opt/polarion/entrypoint.d/*.sh

# Copy startup script to root
COPY polarion_starter.sh ./
RUN sed -i 's/\r//' polarion_starter.sh && chmod +x polarion_starter.sh

# Report health the same way the compose files do (GET /polarion/ over loopback), so a plain
# `docker run` without compose gets a health signal too. The timings deliberately do NOT
# mirror compose's (interval 5s / retries 10 / start_period 10s): that budget is ~60s, while a
# first Polarion boot takes minutes, so it would mark a perfectly good container unhealthy.
# Compose's own healthcheck block still overrides this one for compose users.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=5 \
  CMD ["wget", "-o", "/dev/null", "-O", "/dev/null", "http://localhost/polarion/"]

# Set exposed ports
EXPOSE 80/tcp
# Built-in Mailpit catcher (runs by default; disable with MAILPIT_EMBEDDED=false):
# SMTP on 25, web UI on 8025. Publish -p 8025:8025 to read captured mail from the host.
EXPOSE 25/tcp
EXPOSE 8025/tcp

# No USER directive: this image intentionally runs as root. `service polarion start`,
# `service apache2 start` and the chown/chmod calls across entrypoint.d/ all need it, and
# this is a development tool rather than an internet-facing service — a non-root refactor
# would very likely break the SVN/Apache permission handling in
# entrypoint.d/99-start-polarion.sh. Accepted tradeoff, see issue #89 item 7.

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]
