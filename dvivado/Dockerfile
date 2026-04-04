FROM ubuntu:16.04 AS base

# Dependencies - restored xz-utils to fix payload extraction
RUN apt-get update && apt-get install -y \
    locales \
    libncurses5 \
    libncursesw5 \
    libtinfo5 \
    libcanberra-gtk-module \
    libstdc++6 \
    libstdc++6:i386 \
    libxtst6 \
    libxi6 \
    libxrender1 \
    libxft2 \
    libglib2.0-0 \
    gtk2-engines-pixbuf \
    adwaita-icon-theme \
    libsm6 \
    libice6 \
    libc6-i386 \
    lib32gcc1 \
    lib32stdc++6 \
    libapr1 \
    libaprutil1 \
    libfontconfig1 \
    libfreetype6 \
    libxrandr2 \
    gcc \
    g++ \
    make \
    build-essential \
    libc6-dev \
    net-tools \
    rsync \
    sudo \
    xterm-256color \
    libpng12-0 \
    libjpeg8 \
    libxaw7 \
    fpart \
    && locale-gen en_US.UTF-8 \
    && ln -sf /bin/bash /bin/sh \
    && rm -rf /var/lib/apt/lists/*
    
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

FROM base AS builder
ARG VIVADO_VERSION=2016.3

RUN apt-get update && apt-get install -y unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=installer_dir,target=/mnt/installer \
    --mount=type=bind,from=config_dir,source=config-vivado.ini,target=/opt/config-vivado.ini \
    echo "Query installer contents: " && ls /mnt/installer/ && \
    echo "Query config-vivado.ini: " && ls /opt/config-vivado.ini && \
    /mnt/installer/xsetup \
        --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
        --batch Install \
        --config /opt/config-vivado.ini

# Purge non-essential directories (MicroBlaze/ARM for SDK/embedded C, docs, Windows binaries)
RUN rm -rf /opt/Xilinx/Vivado/${VIVADO_VERSION}/gnu \
    && rm -rf /opt/Xilinx/Vivado/${VIVADO_VERSION}/doc \
    && rm -rf /opt/Xilinx/Vivado/${VIVADO_VERSION}/tps/win64 \
    && rm -rf /opt/Xilinx/SDK

FROM base AS runtime
ARG VIVADO_VERSION=2016.2

COPY --from=builder /opt/Xilinx /opt/Xilinx

RUN echo "vivado() { (source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh && vivado \"\$@\"); }" >> /etc/bash.bashrc

RUN useradd -m -s /bin/bash guest && \
    echo "guest ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    mkdir -p /home/guest/workspace-vivado && \
    mkdir -p /home/guest/.vivado && \
    chown -R guest:guest /home/guest

USER guest
WORKDIR /home/guest

CMD ["/bin/bash"]
