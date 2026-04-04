#!/bin/bash
# scripts/launch.sh — Unified launch script for ISE and Vivado
# Uses environment variables APP_ID, APP_LABEL, and toolkit versions.

set -e

# SESSION CLEANUP & SYNC ───────────────────────────────────────────────────────
cleanup() {
    local exit_code=$?
    # Run the restore sync regardless of success/failure
    /bin/bash /usr/local/bin/migrate.sh "${_WORKSPACE}" "${_CONTAINER_WS}" --restore
    
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] Tool session failed ($exit_code)."
    fi

    # Holds for 10s or until key press
    # This acts as a manual replacement for the broken xterm -hold
    if [ -t 1 ]; then
        echo -e "\n[launch] Session ended. Holding for 10s or press any key."
        read -t 10 -n 1 -s -r || true
    fi
}
trap cleanup EXIT TERM

APP_ID="${APP_ID:-vivado}"
APP_LABEL="${APP_LABEL:-Vivado}"
_WORKSPACE="/mnt/host-workspace-${APP_ID}"
_CONTAINER_WS="/home/guest/workspace-${APP_ID}"

# Migrate workspace into container before tool launch
/bin/bash /usr/local/bin/migrate.sh "${_WORKSPACE}" "${_CONTAINER_WS}" --migrate
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
