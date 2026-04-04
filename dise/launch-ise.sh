#!/bin/bash
# Launch ISE with automatic migrate/restore cycle
set -e

WORKSPACE="/mnt/host-workspace-ise"
CONTAINER_WS="/home/guest/workspace-ise"
ISE_VERSION="${ISE_VERSION:-14.7}"

# Migrate workspace into container
echo "[launch] Migrating workspace..."
bash /usr/local/bin/migrate.sh "$WORKSPACE" --migrate

# Source ISE environment and launch
echo "[launch] Starting ISE..."
source "/opt/Xilinx/${ISE_VERSION}/ISE_DS/settings64.sh"

# Run ISE and restore on exit
trap 'bash /usr/local/bin/migrate.sh "$WORKSPACE" --restore && echo "[launch] Workspace restored. Closing."' EXIT
ise
