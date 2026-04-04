#!/bin/bash
# Launch Vivado with automatic migrate/restore cycle
set -e

WORKSPACE="/mnt/host-workspace-vivado"
CONTAINER_WS="/home/guest/workspace-vivado"
VIVADO_VERSION="${VIVADO_VERSION:-2016.3}"

# Migrate workspace into container
echo "[launch] Migrating workspace..."
bash /usr/local/bin/migrate.sh "$WORKSPACE" --migrate

# Source Vivado environment and launch
echo "[launch] Starting Vivado..."
source "/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh"

# Run Vivado and restore on exit
trap 'bash /usr/local/bin/migrate.sh "$WORKSPACE" --restore && echo "[launch] Workspace restored. Closing."' EXIT
vivado -log /home/guest/.vivado/vivado.log -jou /home/guest/.vivado/vivado.jou
