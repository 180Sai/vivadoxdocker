# Build Orchestrator for Linux Shims
FROM ubuntu:16.04

# Install basic compiler toolchain (including 32-bit and 64-bit support)
RUN apt-get update && apt-get install -y \
    gcc \
    gcc-multilib \
    make \
    libc6-dev \
    libc6-dev-i386 \
    && rm -rf /var/lib/apt/lists/*

# The source and output will be mounted via volumes for persistence
WORKDIR /build
CMD ["make", "clean", "all"]
