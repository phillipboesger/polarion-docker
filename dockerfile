# Explicitly use x86_64 platform for Apple Silicon Macs with Rosetta
FROM --platform=linux/amd64 ubuntu:24.04

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNLEVEL=1

# Install basic dependencies and setup locale
RUN apt-get -y update && \
  apt-get -y install sudo unzip expect curl wget mc nano iputils-ping net-tools iproute2 gnupg software-properties-common locales apache2 libapache2-mod-svn && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8

# Install libc6 and create symlink for 64-bit compatibility
RUN apt-get update \
  && apt-get install -y --no-install-recommends libc6 \
  && mkdir -p /lib64 \
  && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Set locale environment
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Setup working directory
WORKDIR /polarion_root

# Copy and extract Polarion installation files
COPY polarion-linux.zip ./
RUN unzip polarion-linux.zip

# Copy startup scripts and make them executable
COPY polarion_starter.sh ./
COPY install.expect ./Polarion
RUN chmod +x polarion_starter.sh && \
  chmod +x ./Polarion/install.expect

# Download and install OpenJDK 17
RUN wget --no-check-certificate https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.8%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.8_7.tar.gz && \
  mkdir -p /usr/lib/jvm && \
  tar -zxf OpenJDK17U-jdk_x64_linux_hotspot_17.0.8_7.tar.gz -C /usr/lib/jvm

# Configure Java alternatives
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-17.0.8+7/bin/java 100 && \
  update-alternatives --install /usr/bin/jar jar /usr/lib/jvm/jdk-17.0.8+7/bin/jar 100 && \
  update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-17.0.8+7/bin/javac 100 && \
  update-alternatives --set jar /usr/lib/jvm/jdk-17.0.8+7/bin/jar && \
  update-alternatives --set javac /usr/lib/jvm/jdk-17.0.8+7/bin/javac

# Set Java environment variables
ENV JAVA_HOME="/usr/lib/jvm/jdk-17.0.8+7" \
  JDK_HOME="/usr/lib/jvm/jdk-17.0.8+7"

# Add Java environment to system environment
RUN echo "JAVA_HOME=\"$JAVA_HOME\"" >> /etc/environment && \
  echo "JDK_HOME=\"$JDK_HOME\"" >> /etc/environment

# Verify Java installation
RUN echo "JAVA_HOME and JDK_HOME have been successfully set to:" && \
  echo "JAVA_HOME=$JAVA_HOME" && \
  echo "JDK_HOME=$JDK_HOME"   

# Switch to Polarion directory for installation
WORKDIR /polarion_root/Polarion

# Configure policy-rc.d for installation compatibility
RUN printf '#!/bin/sh\nexit 0' > /usr/sbin/policy-rc.d
RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d

# Run Polarion installation
RUN set -x && ./install.expect

# Return to root directory and add PostgreSQL to PATH
WORKDIR /polarion_root
ENV PATH="/usr/lib/postgresql/16/bin:${PATH}"

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]