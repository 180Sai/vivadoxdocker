#!/bin/bash
# scripts/migrate.sh — Concurrent workspace sync with crash-archive support
# Uses environment variables APP_ID and APP_LABEL for tool-specific logic.

set -e

APP_ID="${APP_ID:-vivado}"
APP_LABEL="${APP_LABEL:-Vivado}"
HOST_DIR="${1:-/mnt/host-workspace-${APP_ID}}"
CONTAINER_DIR="${CONTAINER_WS:-/home/guest/workspace-${APP_ID}}"
ARCHIVE_DIR="${CONTAINER_DIR}/.archives"
ENABLE_CRASH_RECOVERY="${ENABLE_CRASH_RECOVERY:-false}"

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

# ─── Tool-Specific Excludes ──────────────────────────────────────────────────
RSYNC_EXCLUDES=(
    "--exclude=host-workspace*"
    "--exclude=mnt.host-workspace*"
    "--exclude=.archives/"
)

if [ "$APP_ID" == "ise" ]; then
    RSYNC_EXCLUDES+=( "--exclude=isim/" "--exclude=_xmsgs/" "--exclude=xst/" "--exclude=_ngo/" "--exclude=*.jfm" "--exclude=.sim/" )
elif [ "$APP_ID" == "vivado" ]; then
    RSYNC_EXCLUDES+=( "--exclude=.Xil/" )
fi

# ─── Synchronization Engine ──────────────────────────────────────────────────
# Uses fpsync (from fpart) if available, falls back to standard rsync
sync_files() {
    local src="$1" dest="$2"
    echo "[sync] Copying ${src} to ${dest}..."

    if command -v fpsync >/dev/null 2>&1; then
        echo "[sync] Engine: Parallel (fpsync)"
        fpsync -n 4 -o "-a --delete ${RSYNC_EXCLUDES[*]} --no-owner --no-group" "$src/" "$dest/"
    else
        echo "[sync] Engine: Sequential (rsync)"
        rsync -a --delete "${RSYNC_EXCLUDES[@]}" --no-owner --no-group --info=progress2 "$src/" "$dest/"
    fi
}

# ─── Prompt helper ───────────────────────────────────────────────────────────
ask_confirm() {
    if [ "${2:-0}" -eq 2 ]; then return 0; fi
    if [ "${2:-0}" -eq 0 ]; then echo "[sync] Skipped (disabled)."; return 1; fi
    # mode == 1: ask
    if [ -t 0 ]; then
        read -r -p "[sync] $1 — proceed? [Y/n] " ans
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
    if [ -d "$CONTAINER_DIR" ] && [ "$(ls -A "$CONTAINER_DIR" 2>/dev/null)" ]; then
        local TS=$(date +%Y%m%d_%H%M%S)
        local TARGET="${ARCHIVE_DIR}/${APP_ID}_recovered_${TS}"
        echo "[sync] CRASH RECOVERY: Found un-restored data. Archiving to ${TARGET}..."
        mkdir -p "$ARCHIVE_DIR"
        mv "$CONTAINER_DIR" "$TARGET"
        echo "[sync] Archiving complete."
    fi
}

# ─── Logic ───────────────────────────────────────────────────────────────────

if [[ "$*" == *"--migrate"* ]]; then
    safeguard "$HOST_DIR" "Host workspace"
    archive_dirty_data

    LIMIT=$((WORKSPACE_MAX_MB * 1024 * 1024))
    HOST_SIZE=$(du -sb "$HOST_DIR" 2>/dev/null | cut -f1)
    if [ "${HOST_SIZE:-0}" -gt "$LIMIT" ]; then
        echo "[sync] ABORT: Workspace exceeds ${WORKSPACE_MAX_MB} MB limit."
        exit 1
    fi

    ask_confirm "Migrate ${HOST_DIR} to container" "${AUTO_MIGRATE}" || exit 0

    mkdir -p "$CONTAINER_DIR"
    chown -R guest:guest "$CONTAINER_DIR" 2>/dev/null || true
    sync_files "$HOST_DIR" "$CONTAINER_DIR"
fi

if [[ "$*" == *"--restore"* ]]; then
    if [ ! -d "$CONTAINER_DIR" ] || [ -z "$(ls -A "$CONTAINER_DIR" 2>/dev/null)" ]; then
        echo "[sync] Container workspace is empty — skipping restore."
        exit 0
    fi
    ask_confirm "Restore ${CONTAINER_DIR} to ${HOST_DIR}" "${AUTO_RESTORE}" || { sleep 1; exit 0; }
    sync_files "$CONTAINER_DIR" "$HOST_DIR"
fi
