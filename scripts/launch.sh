#!/bin/bash
# scripts/launch.sh — Unified launch script for ISE and Vivado
# Uses environment variables APP_ID, APP_LABEL, and toolkit versions.

set -e

APP_ID="${APP_ID:-vivado}"
APP_LABEL="${APP_LABEL:-Vivado}"
WORKSPACE="/mnt/host-workspace-${APP_ID}"
CONTAINER_WS="/home/guest/workspace-${APP_ID}"

# SESSION SYNC ────────────────────────────────────────────────────────────────

# Migrate workspace into container
# echo "[launch] Migrating workspace..."
/usr/local/bin/migrate.sh "$WORKSPACE" "$CONTAINER_WS" --migrate

# Set restore on exit
trap 'bash /usr/local/bin/migrate.sh "$WORKSPACE" "$CONTAINER_WS" --restore' EXIT
# echo "[launch] Workspace restored. Closing."

# TOOL LAUNCH ─────────────────────────────────────────────────────────────────

echo "[launch] Starting $APP_LABEL..."

if [ "$APP_ID" == "ise" ]; then
    ISE_VERSION="${ISE_VERSION:-14.7}"
    source "/opt/Xilinx/${ISE_VERSION}/ISE_DS/settings64.sh"
    ise
elif [ "$APP_ID" == "vivado" ]; then
    VIVADO_VERSION="${VIVADO_VERSION:-2016.3}"
    source "/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh"
    # Launch vivado and keep terminal active for logs
    vivado -log /home/guest/.vivado/vivado.log -jou /home/guest/.vivado/vivado.jou
else
    echo "[launch] ERROR: Unknown APP_ID: $APP_ID"
    exit 1
fi
