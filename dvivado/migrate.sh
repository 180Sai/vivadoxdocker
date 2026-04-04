#!/bin/bash
# dvivado/migrate.sh — Vivado workspace sync (host ↔ Docker volume)

HOST_DIR="${1:-/mnt/host-workspace-vivado}"
CONTAINER_DIR="/home/guest/workspace-vivado"
WORKSPACE_MAX_MB="${WORKSPACE_MAX_MB:-1024}"
AUTO_MIGRATE="${AUTO_MIGRATE:-1}"
AUTO_RESTORE="${AUTO_RESTORE:-2}"

# ─── Safety guards ───────────────────────────────────────────────────────────
# Prevent catastrophic mistakes: reject root, home dir, or non-existent paths
safeguard() {
    local path="$1" label="$2"
    # Must exist
    if [ ! -e "$path" ]; then
        echo "[sync] SAFEGUARD: $label does not exist: $path"
        exit 1
    fi
    # Must be an absolute path
    if [[ "$path" != /* ]]; then
        echo "[sync] SAFEGUARD: $label must be absolute: $path"
        exit 1
    fi
    # Must not be root, /home, /home/guest, or /tmp
    case "$path" in
        /|/home|/home/guest|/home/guest/|/tmp|/tmp/)
            echo "[sync] SAFEGUARD: $label is a protected system path: $path"
            exit 1
            ;;
    esac
}

safeguard "$HOST_DIR" "Host workspace"
safeguard "$CONTAINER_DIR" "Container workspace"

# Smart excludes for workspace sync (ignore broken container-internal symlinks)
RSYNC_EXCLUDES=(
    "--exclude=host-workspace*"
    "--exclude=mnt.host-workspace*"
    "--exclude=.Xil/"
)

# ─── Prompt helper ───────────────────────────────────────────────────────────
ask_confirm() {
    if [ "${2:-0}" -eq 2 ]; then return 0; fi
    if [ "${2:-0}" -eq 0 ]; then echo "[sync] Skipped (disabled)."; return 1; fi
    # mode == 1 → ask
    if [ -t 0 ]; then
        # Standard read (wait for Enter)
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

# Detect unstaged changes between container and host, offer to archive
detect_and_archive() {
    # If container is empty, nothing to detect
    if [ ! -d "$CONTAINER_DIR" ] || [ -z "$(ls -A "$CONTAINER_DIR" 2>/dev/null)" ]; then
        return 0
    fi

    echo "[sync] Checking for unsaved changes in container workspace..."
    # rsync --dry-run to see if container differed from host
    DIFF=$(rsync -a --dry-run --delete --out-format="%n" "$CONTAINER_DIR/" "${HOST_DIR}/" 2>/dev/null)
    if [ -z "$DIFF" ]; then
        echo "[sync] No unsaved changes detected."
        return 0
    fi

    echo "[sync] Found unsaved changes in container:"
    echo "$DIFF" | head -20
    LOCAL_COUNT=$(echo "$DIFF" | wc -l)
    if [ "$LOCAL_COUNT" -gt 20 ]; then
        echo "... and $((LOCAL_COUNT - 20)) more"
    fi

    # Skip archive prompt if auto_migrate is always (2)
    if [ "$AUTO_MIGRATE" -eq 2 ]; then
        echo "[sync] AUTO_MIGRATE=always — skipping archive prompt."
        return 0
    fi
    if [ "$AUTO_MIGRATE" -eq 0 ]; then
        echo "[sync] AUTO_MIGRATE=never — skipping archive."
        return 0
    fi

    # Use ask_confirm helper to handle No-TTY (default to YES)
    ask_confirm "Changes detected in container — Archive these to ${HOST_DIR}?" "1" || return 0

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE_NAME="workspace_backup_${TIMESTAMP}.tar.gz"
    ARCHIVE_PATH="${HOST_DIR}/${ARCHIVE_NAME}"

    echo "[sync] Creating archive: ${ARCHIVE_PATH}..."
    tar -czf "$ARCHIVE_PATH" -C "$CONTAINER_DIR" . 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[sync] Archive saved to: ${ARCHIVE_PATH}"
    else
        echo "[sync] WARNING: Failed to create archive."
    fi
}

if [[ "$*" == *"--migrate"* ]]; then
    # Ensure a convenience shortcut exists in the home directory
    [ -L "/home/guest/mnt.host-workspace" ] || ln -sf "$HOST_DIR" "/home/guest/mnt.host-workspace"

    echo "[sync] Checking workspace size..."
    LIMIT=$((WORKSPACE_MAX_MB * 1024 * 1024))
    HOST_SIZE=$(du -sb "$HOST_DIR" 2>/dev/null | cut -f1)
    if [ "${HOST_SIZE:-0}" -gt "$LIMIT" ]; then
        echo "[sync] ABORT: Workspace exceeds ${WORKSPACE_MAX_MB} MB limit ($(du -sh "$HOST_DIR" | cut -f1))."
        exit 1
    fi
    ask_confirm "Migrate ${HOST_DIR} to container" "${AUTO_MIGRATE}" || exit 0
    echo "[sync] Copying ${HOST_DIR} to ${CONTAINER_DIR}..."
    mkdir -p "$CONTAINER_DIR"
    chown -R guest:guest "$CONTAINER_DIR" 2>/dev/null || true
    rsync -a "${RSYNC_EXCLUDES[@]}" --no-owner --no-group --info=progress2 "${HOST_DIR}/" "$CONTAINER_DIR/"
    echo "[sync] Done."
fi

if [[ "$*" == *"--restore"* ]]; then
    # Never restore from an empty container (would wipe host with --delete)
    if [ ! -d "$CONTAINER_DIR" ] || [ -z "$(ls -A "$CONTAINER_DIR" 2>/dev/null)" ]; then
        echo "[sync] SAFEGUARD: Container workspace is empty — skipping restore to protect host data."
        exit 0
    fi
    ask_confirm "Restore ${CONTAINER_DIR} to ${HOST_DIR}" "${AUTO_RESTORE}" || { sleep 1; exit 0; }
    echo "[sync] Copying ${CONTAINER_DIR} to ${HOST_DIR}..."
    rsync -a "${RSYNC_EXCLUDES[@]}" --no-owner --no-group --info=progress2 "$CONTAINER_DIR/" "${HOST_DIR}/"
    echo "[sync] Done."
    sleep 1
fi
