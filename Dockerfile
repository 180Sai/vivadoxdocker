FROM ubuntu:16.04

ARG INSTALLER_DIR=Xilinx_Vivado_SDK_2016.2_0605_1
ARG CONFIG=config.ini

# Dependencies + VNC/noVNC
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
    sudo \
    unzip \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Run installer silently using bind-mounted installer directory
RUN --mount=type=bind,source=.,target=/mnt/installer \
    echo "Files visible in mount:" && ls /mnt/installer/ && \
    echo "Query ${INSTALLER_DIR} contents: " && ls /mnt/installer/${INSTALLER_DIR}/ && \
    echo "Query $CONFIG: " && ls /mnt/installer/${CONFIG} && \
    /mnt/installer/${INSTALLER_DIR}/xsetup \
        --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
        --batch Install \
        --config /mnt/installer/${CONFIG}

# Source Vivado settings for every shell session
RUN echo 'vivado() { (source /opt/Xilinx/Vivado/2016.2/settings64.sh && vivado "$@"); }' >> /etc/bash.bashrc

# Create guest user
RUN useradd -m -s /bin/bash guest && \
    echo "guest ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER guest
WORKDIR /home/guest/workspace

EXPOSE 6080 5900

CMD ["/bin/bash"]
