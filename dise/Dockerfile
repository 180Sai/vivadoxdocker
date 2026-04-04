FROM ubuntu:14.04 AS base

# Dependencies: legacy 32-bit multiarch libraries, older standard C libraries
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y \
    locales \
    libncurses5 \
    libncurses5:i386 \
    libstdc++5 \
    libstdc++5:i386 \
    libstdc++6 \
    libstdc++6:i386 \
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
    libxext6:i386 \
    libpng12-0 \
    libpng12-0:i386 \
    libgtk2.0-0:i386 \
    gtk2-engines-pixbuf \
    gtk2-engines-pixbuf:i386 \
    libcanberra-gtk-module:i386 \
    humanity-icon-theme \
    ubuntu-mono \
    libc6-i386 \
    lib32gcc1 \
    libmotif-dev \
    gcc \
    g++ \
    libc6-dev \
    libc6-dev-i386 \
    rsync \
    xterm \
    fpart \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf bash /bin/sh

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

FROM base AS builder

ARG ISE_VERSION=14.7

RUN apt-get update && apt-get install -y unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=installer_dir,target=/mnt/installer \
    --mount=type=bind,from=config_dir,source=config-ise.ini,target=/opt/config-ise.ini \
    echo "Query installer contents: " && ls /mnt/installer/ && \
    echo "Query config-ise.ini: " && ls /opt/config-ise.ini && \
    yes "Y" | TERM=xterm /mnt/installer/bin/lin64/batchxsetup \
        --batch /opt/config-ise.ini

# Purge non-essential tooling directories (MicroBlaze, tutorials, SysGen, ARM/PowerPC)
RUN rm -rf /opt/Xilinx/${ISE_VERSION}/ISE_DS/ISE/gnu \
    && rm -rf /opt/Xilinx/${ISE_VERSION}/ISE_DS/EDK/gnu \
    && rm -rf /opt/Xilinx/${ISE_VERSION}/ISE_DS/ISE/doc \
    && rm -rf /opt/Xilinx/${ISE_VERSION}/ISE_DS/ISE/sysgen/examples

FROM base AS runtime

ARG ISE_VERSION=14.7

COPY --from=builder /opt/Xilinx /opt/Xilinx

RUN echo "ise() { (source /opt/Xilinx/${ISE_VERSION}/ISE_DS/settings64.sh && ise \"\$@\"); }" >> /etc/bash.bashrc

ENV XILINXD_LICENSE_FILE=/home/guest/.Xilinx/Xilinx.lic

RUN useradd -m -s /bin/bash guest && \
    mkdir -p /home/guest/workspace-ise && \
    mkdir -p /home/guest/.Xilinx && \
    chown -R guest:guest /home/guest

USER guest
WORKDIR /home/guest

CMD ["/bin/bash"]
