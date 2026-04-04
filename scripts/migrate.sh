#!/bin/bash
# scripts/migrate.sh — Concurrent workspace sync with crash-archive support
# Uses environment variables APP_ID and APP_LABEL for tool-specific logic.

set -e
shopt -s extglob 2>/dev/null || true
shopt -s dotglob 2>/dev/null || true

APP_ID="${APP_ID:-vivado}"
APP_LABEL="${APP_LABEL:-Vivado}"

# ─── Error Handling ──────────────────────────────────────────────────────────
# Keep terminal open on failure to allow reading logs
failure_handler() {
    local code=$?
    if [ $code -ne 0 ] && [ $code -ne 130 ]; then
        echo "[sync] ERROR: Synchronization process failed ($code)."
        echo "[sync] Window will hold for 10s..."
        sleep 10
    fi
}
trap failure_handler EXIT

HOST_DIR="${1:-/mnt/host-workspace-${APP_ID}}"
CONTAINER_DIR="${CONTAINER_WS:-/home/guest/workspace-${APP_ID}}"
ARCHIVE_DIR="${HOST_DIR}/.archives"
ENABLE_CRASH_RECOVERY="${ENABLE_CRASH_RECOVERY:-false}"
RSYNC_ARCHIVE_INCLUDE="${RSYNC_ARCHIVE_INCLUDE:-*.vhd *.v *.sv *.xpr *.xise *.xci *.xdc *.ucf *.tcl *.sh *.wcfg *.coe *.mem}"
RSYNC_EXCLUDES="${RSYNC_EXCLUDES:-host-workspace* mnt.host-workspace* .archives/ .Xil/ isim/ _xmsgs/ xst/ _ngo/ *.jfm .sim/}"

# POSITIONAL ARGUMENT PARSING
if [[ "$2" != --* ]] && [[ -n "$2" ]]; then
    CONTAINER_DIR="$2"
fi

WORKSPACE_MAX_MB="${WORKSPACE_MAX_MB:-1024}"
AUTO_MIGRATE="${AUTO_MIGRATE:-2}"
AUTO_RESTORE="${AUTO_RESTORE:-1}"

# ─── Safety guards ───────────────────────────────────────────────────────────
safeguard() {
    local path="$1" label="$2"
    if [ ! -e "$path" ]; then
        echo "[sync] SAFEGUARD: $label does not exist: $path"
        exit 1
    fi
}


# ─── Synchronization Engine ──────────────────────────────────────────────────
# Primarily uses rsync with progress reporting.
sync_files() {
    local src="$1" dest="$2"
    echo "[sync] Copying ${src} to ${dest}..."

    # Ensure destination exists
    mkdir -p "$dest" 2>/dev/null || true

    local _EXCL_ARGS=()
    for pat in $RSYNC_EXCLUDES; do
        _EXCL_ARGS+=( "--exclude=$pat" )
    done

    echo "[sync] Engine: Sequential (rsync)"
    rsync -a --delete "${_EXCL_ARGS[@]}" --no-owner --no-group --info=progress2 "$src/" "$dest/"
    
    echo "[sync] Completed: $(date +%H:%M:%S)"
}

# ─── Prompt helper ───────────────────────────────────────────────────────────
ask_confirm() {
    if [ "${2:-0}" -eq 2 ]; then return 0; fi
    if [ "${2:-0}" -eq 0 ]; then echo "[sync] Skipped (disabled)."; return 1; fi
    # mode == 1: ask
    if [ -t 0 ]; then
        read -r -p "[sync] $1, proceed? [Y/n] " ans
        if [[ "$ans" =~ ^[Nn] ]]; then
            echo "[sync] Skipped by user."
            return 1
        fi
        return 0
    else
        echo "[sync] $1 — No TTY detected, defaulting to YES."
        return 0
    fi
}

# ─── Recovery Archive ────────────────────────────────────────────────────────
# Moves an un-restored container workspace to a timestamped backup folder
archive_dirty_data() {
    [ "$ENABLE_CRASH_RECOVERY" == "true" ] || return 0
    local LOG="${ARCHIVE_DIR}/restore.log"
    
    # Check if files exist (ignoring recovery archives)
    if [ -d "$CONTAINER_DIR" ] && [ "$(ls -A "$CONTAINER_DIR" 2>/dev/null | grep -Ev '^\.archives$')" ]; then
        # Check the log for the last recorded status of this APP_ID
        if [ -f "$LOG" ]; then
            # Search for the ID with flexible whitespace anchoring
            local LAST_STATUS=$(grep -E "\|[[:space:]]*${APP_ID}[[:space:]]*\|" "$LOG" | tail -n 1 | awk -F'|' '{print $3}' | xargs)
            if [ "$LAST_STATUS" == "RESTORED" ]; then
                echo "[sync] Previous session for ${APP_ID} was restored successfully."
                return 0
            fi
        fi

        local TS=$(date +%Y%m%d_%H%M%S)
        local TARGET="${ARCHIVE_DIR}/${APP_ID}_recovered_${TS}"
        echo "[sync] CRASH RECOVERY: Found un-restored data. Archiving to ${TARGET}..."
        mkdir -p "$TARGET"
        
        # Build inclusion arguments from the variable
        local ARCHIVE_ARGS=( --include="*/" )
        for pat in $RSYNC_ARCHIVE_INCLUDE; do
            ARCHIVE_ARGS+=( --include="$pat" )
        done
        
        # Move ONLY source files based on the list
        rsync -a --remove-source-files "${ARCHIVE_ARGS[@]}" --info=progress2 --exclude="*" \
            "$CONTAINER_DIR/" "$TARGET/"

        # Cleanup remaining artifacts/directories
        find "$CONTAINER_DIR" -depth -mindepth 1 -not -path "${ARCHIVE_DIR}*" -delete
        echo "[sync] Archiving complete."
    fi
}

# ─── Logic ───────────────────────────────────────────────────────────────────

if [[ "$*" == *"--migrate"* ]]; then
    # Start high-latency disk check in background immediately
    (
        _DU_EXCL=()
        for pat in $RSYNC_EXCLUDES; do _DU_EXCL+=( "--exclude=$pat" ); done
        du -sb "${_DU_EXCL[@]}" "$HOST_DIR" 2>/dev/null | cut -f1 > "/tmp/du_size_${APP_ID}"
    ) &
    DU_PID=$!

    safeguard "$HOST_DIR" "Host workspace"
    archive_dirty_data

    # Wait for the background size check to complete
    wait $DU_PID
    HOST_SIZE=$(cat "/tmp/du_size_${APP_ID}")
    rm -f "/tmp/du_size_${APP_ID}"

    LIMIT=$((WORKSPACE_MAX_MB * 1024 * 1024))
    if [ "${HOST_SIZE:-0}" -gt "$LIMIT" ]; then
        echo "[sync] ABORT: Workspace exceeds ${WORKSPACE_MAX_MB} MB limit."
        exit 1
    fi

    ask_confirm "Migrate ${HOST_DIR} to container" "${AUTO_MIGRATE}" || exit 0

    mkdir -p "$CONTAINER_DIR"
    chown -R guest:guest "$CONTAINER_DIR" 2>/dev/null || true
    sync_files "$HOST_DIR" "$CONTAINER_DIR"
    
    # Log the migration
    mkdir -p "$ARCHIVE_DIR"
    printf "[%s] | %s | %-10s | %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$APP_ID" "MIGRATED" "Host workspace synced to container" >> "${ARCHIVE_DIR}/restore.log"
fi

if [[ "$*" == *"--restore"* ]]; then
    if [ ! -d "$CONTAINER_DIR" ] || [ -z "$(ls -A "$CONTAINER_DIR" 2>/dev/null)" ]; then
        echo "[sync] Container workspace is empty, skipping restore."
        exit 0
    fi
    ask_confirm "Restore ${CONTAINER_DIR} to ${HOST_DIR}" "${AUTO_RESTORE}" || { sleep 1; exit 0; }
    sync_files "$CONTAINER_DIR" "$HOST_DIR"
    
    # Mark as restored so next startup doesn't trigger crash recovery
    mkdir -p "$ARCHIVE_DIR"
    printf "[%s] | %s | %-10s | %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$APP_ID" "RESTORED" "Container workspace restored to host" >> "${ARCHIVE_DIR}/restore.log"
fi
