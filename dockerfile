# Base image for Polarion Docker container
FROM ubuntu:24.04

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
  update-locale LANG=en_US.UTF-8

# Install libc6 and create symlink for 64-bit compatibility
RUN apt-get install -y --no-install-recommends libc6 && \
  mkdir -p /lib64 && \
  ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Set locale environment
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup working directory
WORKDIR /polarion_root

# Copy and extract Polarion installation files (downloaded in CI from Google Drive)
COPY polarion-linux.zip ./
RUN unzip -q polarion-linux.zip && \
  echo "=== Contents after unzip ===" && \
  ls -la ./ && \
  echo "=== Looking for install.sh ===" && \
  find . -name "install.sh" -type f

# Copy startup script to root
COPY polarion_starter.sh ./
RUN chmod +x polarion_starter.sh

# Download and install OpenJDK 21 (Temurin)
RUN wget --no-check-certificate https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz && \
  mkdir -p /usr/lib/jvm && \
  tar -zxf OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz -C /usr/lib/jvm

# Configure Java alternatives for JDK 21
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-21.0.4+7/bin/java 100 && \
  update-alternatives --install /usr/bin/jar jar /usr/lib/jvm/jdk-21.0.4+7/bin/jar 100 && \
  update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-21.0.4+7/bin/javac 100 && \
  update-alternatives --set jar /usr/lib/jvm/jdk-21.0.4+7/bin/jar && \
  update-alternatives --set javac /usr/lib/jvm/jdk-21.0.4+7/bin/javac

# Set Java environment variables
ENV JAVA_HOME="/usr/lib/jvm/jdk-21.0.4+7" \
  JDK_HOME="/usr/lib/jvm/jdk-21.0.4+7"

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

# Apache-Setup wird vorerst deaktiviert, um zu sehen,
# wie weit Polarion seine eigene Apache-Installation übernimmt.
## Configure Apache for Docker environment
# RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
#   mkdir -p /var/run/apache2 && \
#   mkdir -p /var/lock/apache2 && \
#   chown -R www-data:www-data /var/run/apache2 /var/lock/apache2

## Configure policy-rc.d for installation compatibility
# RUN printf '#!/bin/sh\nexit 0' > /usr/sbin/policy-rc.d && \
#   chmod +x /usr/sbin/policy-rc.d

## Create Apache service wrapper that works in Docker
# RUN printf '#!/bin/bash\n\
#   case "$1" in\n\
#   start|restart|reload)\n\
#   mkdir -p /var/run/apache2\n\
#   mkdir -p /var/lock/apache2\n\
#   chown -R www-data:www-data /var/run/apache2 /var/lock/apache2\n\
#   /usr/sbin/apache2ctl start 2>/dev/null || /usr/sbin/apache2ctl restart 2>/dev/null || true\n\
#   ;;\n\
#   stop)\n\
#   /usr/sbin/apache2ctl stop 2>/dev/null || true\n\
#   ;;\n\
#   status)\n\
#   /usr/sbin/apache2ctl status 2>/dev/null || echo "Apache is running"\n\
#   ;;\n\
#   *)\n\
#   echo "Usage: $0 {start|stop|restart|reload|status}"\n\
#   ;;\n\
#   esac\n\
#   exit 0' > /etc/init.d/apache2 && \
#   chmod +x /etc/init.d/apache2

## Override the service command to use our wrapper
# RUN printf '#!/bin/bash\n\
#   if [ "$1" = "apache2" ]; then\n\
#   /etc/init.d/apache2 "$2"\n\
#   else\n\
#   /usr/sbin/service "$@"\n\
#   fi' > /usr/local/bin/service && \
#   chmod +x /usr/local/bin/service && \
#   ln -sf /usr/local/bin/service /usr/bin/service

## Start Apache before installation
# RUN /etc/init.d/apache2 start

# Run Polarion installation
RUN set -x && ./install.expect

# Return to root directory and add PostgreSQL 16 to PATH
WORKDIR /polarion_root
ENV PATH="/usr/lib/postgresql/16/bin:${PATH}"

# Set environment variables for debugging support (default: enabled)
ENV JDWP_ENABLED="true"

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]