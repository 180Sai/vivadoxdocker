FROM ubuntu:14.04
ARG ISE_VERSION=14.7

# ISE deeply requires legacy 32-bit multiarch libraries and older standard C libraries
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y \
    locales \
    libncurses5 \
    libncurses5:i386 \
    libstdc++5 \
    libstdc++5:i386 \
    lib32stdc++6 \
    lib32z1 \
    libcanberra-gtk-module \
    libxtst6 \
    libxtst6:i386 \
    libxi6 \
    libxi6:i386 \
    libxrender1 \
    libxrender1:i386 \
    libxrandr2 \
    libxrandr2:i386 \
    libxft2 \
    libglib2.0-0 \
    libglib2.0-0:i386 \
    libsm6 \
    libsm6:i386 \
    libice6 \
    libx11-6 \
    libx11-6:i386 \
    libfontconfig1 \
    libfontconfig1:i386 \
    libxext6 \
    libc6-i386 \
    lib32gcc1 \
    libmotif-dev \
    gcc \
    g++ \
    sudo \
    unzip \
    xz-utils \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Run installer silently using bind-mounted installer directory and config-context
# Note: from=installer_dir and from=config_dir use additional contexts defined in docker-compose.yml
RUN --mount=type=bind,from=installer_dir,target=/mnt/installer \
    --mount=type=bind,from=config_dir,source=config-ise.ini,target=/opt/config-ise.ini \
    echo "Query installer contents: " && ls /mnt/installer/ && \
    echo "Query config-ise.ini: " && ls /opt/config-ise.ini && \
    yes "Y" | TERM=xterm /mnt/installer/bin/lin64/batchxsetup \
        --batch /opt/config-ise.ini

# Source ISE settings for every shell session
RUN echo "ise() { (source /opt/Xilinx/${ISE_VERSION}/ISE_DS/settings64.sh && ise \"\$@\"); }" >> /etc/bash.bashrc

# Create guest user
RUN useradd -m -s /bin/bash guest && \
    echo "guest ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER guest
WORKDIR /home/guest

EXPOSE 6080 5900

CMD ["/bin/bash"]
