# Base image for Polarion Docker container
ARG SOURCE_IMAGE=ubuntu:24.04
# SOURCE_IMAGE defaults to the tagged ubuntu:24.04 above; the ARG indirection is what
# trips DL3006 (hadolint can't see the default tag), so the warning is a false positive.
# hadolint ignore=DL3006
FROM $SOURCE_IMAGE

# Temurin JDK download metadata — choose appropriate archive at build time
ARG JDK_TAG=jdk-21.0.4%2B7
ARG JDK_FILE_X64=OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz
ARG JDK_FILE_AARCH64=OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.4_7.tar.gz

# Mailpit version for the optional embedded mail catcher (enabled at runtime via
# MAILPIT_EMBEDDED=true). Defaults to "latest" so each image build picks up the
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
RUN apt-get -y update && \
	apt-get -y install --no-install-recommends sudo unzip expect wget locales libc6 \
	apache2 subversion libapache2-mod-svn libswt-gtk-4-java apache2-utils libaprutil1-dbd-pgsql \
	postgresql postgresql-client postgresql-contrib util-linux-extra iputils-ping && \
	locale-gen en_US.UTF-8 && \
	update-locale LANG=en_US.UTF-8 && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Add postgres symlink for genericity
RUN ln -s /usr/lib/postgresql/* /usr/lib/postgresql/current

# Set locale environment
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup working directory
WORKDIR /polarion_root

# Copy modular entrypoint scripts
COPY entrypoint.d/ /opt/polarion/entrypoint.d/
RUN sed -i 's/\r//' /opt/polarion/entrypoint.d/*.sh && chmod +x /opt/polarion/entrypoint.d/*.sh

# Copy startup script to root
COPY polarion_starter.sh ./
RUN sed -i 's/\r//' polarion_starter.sh && chmod +x polarion_starter.sh

# Download and install OpenJDK 21 (Temurin)
# Select the correct archive for the image architecture (x86_64 vs aarch64)
RUN set -eux; \
	arch="$(uname -m)"; \
	if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then \
		jdk_file="$JDK_FILE_X64"; \
	elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then \
		jdk_file="$JDK_FILE_AARCH64"; \
	else \
		echo "Unsupported architecture: $arch"; exit 1; \
	fi; \
	wget --progress=dot:giga -O jdk.tar.gz --no-check-certificate "https://github.com/adoptium/temurin21-binaries/releases/download/${JDK_TAG}/${jdk_file}"; \
	mkdir -p /usr/lib/jvm; \
	tar -zxf jdk.tar.gz -C /usr/lib/jvm; \
	rm jdk.tar.gz

# Configure Java alternatives for JDK 21
RUN ln -s /usr/lib/jvm/* /usr/lib/jvm/current && \
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

# Install the Mailpit binary for the optional embedded mail catcher.
# It is dormant unless MAILPIT_EMBEDDED=true is set at runtime (entrypoint.d/60-mailpit.sh).
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

# Unzip Polarion and install it
# Polarion's installer unpacks a "Polarion" dir during this same RUN, under a transient
# bind-mount; WORKDIR can't target a dir created mid-RUN, so DL3003 is unavoidable here.
# hadolint ignore=DL3003
RUN --mount=type=bind,source=./data/,target=/data/ \
	set -x && \
	unzip -q "$(find /data -iname "polarion*.zip")" && \
	cd Polarion && \
	../install.expect || true && \
	test -d /opt/polarion/polarion && \
	test -d /opt/polarion/data/svn && \
	cd .. && \
	rm -r Polarion && \
	mkdir -p /opt/polarion/bootstrap/svn && \
	cp -a /opt/polarion/data/svn/. /opt/polarion/bootstrap/svn/ && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Add PostgreSQL to PATH
ENV PATH="/usr/lib/postgresql/current/bin:${PATH}"

# Set environment variables for debugging support (default: enabled)
ENV JDWP_ENABLED="true"

# Set exposed ports
EXPOSE 80/tcp
# Optional embedded Mailpit catcher (only active when MAILPIT_EMBEDDED=true):
# SMTP on 25, web UI on 8025. Publish these with -p to use them from the host.
EXPOSE 25/tcp
EXPOSE 8025/tcp

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]
