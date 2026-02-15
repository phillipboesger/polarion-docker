# Base image for Polarion Docker container
ARG SOURCE_IMAGE=ubuntu:24.04
FROM $SOURCE_IMAGE

ARG JDK_SOURCE=https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNLEVEL=1

# Configure apt to be more resilient
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
	echo 'Acquire::http::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries && \
	echo 'Acquire::ftp::Timeout "120";' >> /etc/apt/apt.conf.d/80-retries

# Install basic dependencies and setup locale
RUN apt-get -y update && \
	apt-get -y install sudo unzip expect curl wget mc nano iputils-ping net-tools iproute2 gnupg software-properties-common locales \
	apache2 subversion libapache2-mod-svn libswt-gtk-4-java apache2-utils libaprutil1-dbd-pgsql systemd \
	postgresql postgresql-client postgresql-contrib && \
	locale-gen en_US.UTF-8 && \
	update-locale LANG=en_US.UTF-8 && \
	apt-get install -y --no-install-recommends libc6 && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Create libc6 symlink for 64-bit compatibility and postgres symlink for genericity
RUN mkdir -p /lib64 && \
	ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2 && \
	ln -sf /usr/lib/postgresql/* /usr/lib/postgresql/current

# Set locale environment
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup working directory
WORKDIR /polarion_root

# Extract Polarion installation files
# Supports local build by picking up any zip starting with "polarion" or "Polarion"
RUN --mount=type=bind,source=./data/,target=/data/ \
	unzip -q "$(find /data -iname polarion*.zip)" && \
	echo "=== Contents after unzip ===" && \
	ls -la ./ && \
	echo "=== Looking for install.sh ===" && \
	find . -name "install.sh" -type f

# Copy modular entrypoint scripts
COPY entrypoint.d/ /opt/polarion/entrypoint.d/
RUN chmod +x /opt/polarion/entrypoint.d/*.sh

# Copy startup script to root
COPY polarion_starter.sh ./
RUN chmod +x polarion_starter.sh

# Download and install OpenJDK 21 (Temurin)
RUN wget -O jdk.tar.gz --no-check-certificate "${JDK_SOURCE}" && \
	mkdir -p /usr/lib/jvm && \
	tar -zxf jdk.tar.gz -C /usr/lib/jvm && \
	rm jdk.tar.gz

# Configure Java alternatives for JDK 21
RUN ln -sf /usr/lib/jvm/* /usr/lib/jvm/current && \
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

# Switch to Polarion directory for installation
WORKDIR /polarion_root/Polarion

# Copy install.expect to Polarion directory and make both scripts executable
COPY install.expect ./
RUN echo "=== Current directory contents ===" && \
	ls -la && \
	echo "=== Making scripts executable ===" && \
	chmod +x install.expect && \
	if [ -f install.sh ]; then chmod +x install.sh; else echo "WARNING: install.sh not found!"; fi

# Run Polarion installation
RUN set -x && ./install.expect

# Return to root directory and add PostgreSQL 16 to PATH
WORKDIR /polarion_root
ENV PATH="/usr/lib/postgresql/current/bin:${PATH}"

# Set environment variables for debugging support (default: enabled)
ENV JDWP_ENABLED="true"

# Set exposed ports
EXPOSE 80/tcp

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]
