# Base image for Polarion Docker container
ARG SOURCE_IMAGE=ubuntu:24.04
# SOURCE_IMAGE defaults to the tagged ubuntu:24.04; the ARG is intentionally overridable.
# hadolint ignore=DL3006
FROM $SOURCE_IMAGE

# Polarion installer archive to use, relative to the bind-mounted data/ directory
# (e.g. POLARION_ZIP=PolarionALM_2512.zip). When empty, the build falls back to the
# single-file glob below, preserving the previous behaviour.
ARG POLARION_ZIP=

# Temurin JDK download metadata — choose appropriate archive at build time
ARG JDK_TAG=jdk-21.0.4%2B7
ARG JDK_FILE_X64=OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz
ARG JDK_FILE_AARCH64=OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.4_7.tar.gz

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

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]
