FROM ubuntu:16.04 AS base

# Dependencies - restored xz-utils to fix payload extraction
RUN apt-get update && apt-get install -y \
    locales \
    libncurses5 \
    libncursesw5 \
    libtinfo5 \
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
    && locale-gen en_US.UTF-8 \
    && ln -sf /bin/bash /bin/sh \
    && rm -rf /var/lib/apt/lists/*
    
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Run installer silently using bind-mounted installer directory and config-context
# Note: from=installer_dir and from=config_dir use additional contexts defined in docker-compose.yml
FROM base AS builder
ARG VIVADO_VERSION=2016.2

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

# Copy only essential files to final stage
COPY --from=builder /opt/Xilinx /opt/Xilinx

# Source Vivado settings for every shell session
RUN echo "vivado() { (source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh && vivado \"\$@\"); }" >> /etc/bash.bashrc

# Create guest user
RUN useradd -m -s /bin/bash guest && \
    echo "guest ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER guest
WORKDIR /home/guest

EXPOSE 6080 5900

CMD ["/bin/bash"]
