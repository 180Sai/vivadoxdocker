#!/bin/bash
# dise/migrate_workspace.sh — Specialized workspace migration for ISE

WORKSPACE="/home/guest/workspace"
TARGET_BASE="/home/guest/.vivado_local"
mkdir -p "$TARGET_BASE"

is_nonposix() {
    local fs_type
    fs_type=$(stat -f -c %T "$1" 2>/dev/null)
    case "$fs_type" in
        ntfs|fuseblk|cifs|vboxsf|msdos|vfat) return 0 ;;
        *) return 1 ;;
    esac
}

migrate_once() {
    # Passive Mode: Prepare the local storage base only.
    # The Stealth Shim handles all live build/sim redirection.
    mkdir -p "$TARGET_BASE"
}

# Ensure all local targets are executable
chmod -R +x "$TARGET_BASE" 2>/dev/null

# Restore Mode Check
if [[ "$*" == *"--restore"* ]]; then
    echo "[migration] Restore: writing back ISE resources..."
    find "$WORKSPACE" -maxdepth 3 -name '*.xise' 2>/dev/null | while read -r pfile; do
        PRJ_DIR="$(dirname "$pfile")"
        # Restore everything that looks like a symlink back to our TARGET_BASE
        find "$PRJ_DIR" -maxdepth 1 -type l | while read -r link; do
            TARGET="$(readlink "$link")"
            if [[ "$TARGET" == "$TARGET_BASE"* ]]; then
                echo "[migration] Restoring $(basename "$link")..."
                if [ -d "$TARGET" ]; then
                    mkdir -p "$link.tmp_restore"
                    cp -rn "$TARGET/." "$link.tmp_restore/" 2>/dev/null
                    rm -f "$link"
                    mv "$link.tmp_restore" "$link"
                else
                    cp -n "$TARGET" "$link" 2>/dev/null
                    rm -f "$link"
                fi
            fi
        done
    done
    exit 0
fi

if [ "$AUTO_MIGRATE" == "true" ]; then
    migrate_once
    if [[ "$*" == *"--watch"* ]]; then
        echo "[migration] Background watcher active (ISE). Scanning every 2s..."
        while true; do sleep 2; migrate_once; done
    fi
fi
