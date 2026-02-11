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

# Copy and extract Polarion installation files
COPY polarion*.zip ./
RUN unzip -q polarion*.zip && \
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

# --- JAVA 17 SECTION START ---
# Download and install OpenJDK 17 (Temurin LTS)
RUN wget --no-check-certificate https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.14_7.tar.gz && \
	mkdir -p /usr/lib/jvm && \
	tar -zxf OpenJDK17U-jdk_x64_linux_hotspot_17.0.14_7.tar.gz -C /usr/lib/jvm && \
	rm OpenJDK17U-jdk_x64_linux_hotspot_17.0.14_7.tar.gz

# Configure Java alternatives for JDK 17
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/jdk-17.0.14+7/bin/java 100 && \
	update-alternatives --install /usr/bin/jar jar /usr/lib/jvm/jdk-17.0.14+7/bin/jar 100 && \
	update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/jdk-17.0.14+7/bin/javac 100 && \
	update-alternatives --set jar /usr/lib/jvm/jdk-17.0.14+7/bin/jar && \
	update-alternatives --set javac /usr/lib/jvm/jdk-17.0.14+7/bin/javac

# Set Java environment variables
ENV JAVA_HOME="/usr/lib/jvm/jdk-17.0.14+7" \
	JDK_HOME="/usr/lib/jvm/jdk-17.0.14+7"
# --- JAVA 17 SECTION END ---

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

# Copy install.expect to Polarion directory and make scripts executable
COPY install.expect ./
RUN chmod +x install.expect && \
	if [ -f install.sh ]; then chmod +x install.sh; fi

# Run Polarion installation
RUN set -x && ./install.expect

# Return to root directory and add PostgreSQL 16 to PATH
WORKDIR /polarion_root
ENV PATH="/usr/lib/postgresql/16/bin:${PATH}"

# Set environment variables for debugging support
ENV JDWP_ENABLED="true"

# Set startup command
ENTRYPOINT ["./polarion_starter.sh"]
