FROM ubuntu:16.04
ARG VIVADO_VERSION=2016.2
# Dependencies - restored xz-utils to fix payload extraction
RUN apt-get update && apt-get install -y \
    locales \
    libncurses5 \
    libncursesw5 \
    libcanberra-gtk-module \
    libxtst6 \
    libxi6 \
    libxrender1 \
    libxft2 \
    libglib2.0-0 \
    libsm6 \
    libice6 \
    libc6-i386 \
    lib32gcc1 \
    lib32stdc++6 \
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
    --mount=type=bind,from=config_dir,source=config-vivado.ini,target=/opt/config-vivado.ini \
    echo "Query installer contents: " && ls /mnt/installer/ && \
    echo "Query config-vivado.ini: " && ls /opt/config-vivado.ini && \
    /mnt/installer/xsetup \
        --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
        --batch Install \
        --config /opt/config-vivado.ini

# Source Vivado settings for every shell session
RUN echo "vivado() { (source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh && vivado \"\$@\"); }" >> /etc/bash.bashrc

# Create guest user
RUN useradd -m -s /bin/bash guest && \
    echo "guest ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER guest
WORKDIR /home/guest

EXPOSE 6080 5900

CMD ["/bin/bash"]
