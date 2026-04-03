#!/bin/bash
# dvivado/migrate_workspace.sh — Specialized workspace migration for Vivado

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
    # Find all .xpr (Vivado) projects
    find "$WORKSPACE" -maxdepth 3 -name '*.xpr' 2>/dev/null | while read -r pfile; do
        PRJ_DIR="$(dirname "$pfile")"
        if ! is_nonposix "$PRJ_DIR"; then continue; fi
        
        PRJ_NAME="$(basename "$pfile" .xpr)"
        
        # Check and migrate standard Vivado folders
        # Targets: .sim and .runs directories
        for sub in "${PRJ_NAME}.sim" "${PRJ_NAME}.runs"; do
            SRC_DIR="$PRJ_DIR/$sub"
            DST_DIR="$TARGET_BASE/${PRJ_NAME}_${sub}"
            
            if [ -d "$SRC_DIR" ] && [ ! -L "$SRC_DIR" ]; then
                echo "[migration] Claiming Vivado directory: $sub"
                mkdir -p "$DST_DIR"
                cp -rn "$SRC_DIR/." "$DST_DIR/" 2>/dev/null && rm -rf "$SRC_DIR"
                ln -s "$DST_DIR" "$SRC_DIR"
            fi
        done
    done
}

# Restore Mode Check
if [[ "$*" == *"--restore"* ]]; then
    echo "[migration] Restore: writing back Vivado resources..."
    find "$WORKSPACE" -maxdepth 3 -name '*.xpr' 2>/dev/null | while read -r pfile; do
        PRJ_DIR="$(dirname "$pfile")"
        PRJ_NAME="$(basename "$pfile" .xpr)"
        for sub in "${PRJ_NAME}.sim" "${PRJ_NAME}.runs"; do
            SD="$PRJ_DIR/$sub"
            if [ -L "$SD" ]; then
                TARGET_DIR="$(readlink "$SD")"
                if [[ "$TARGET_DIR" == "$TARGET_BASE"* ]]; then
                    echo "[migration] Restoring $sub..."
                    mkdir -p "$SD.tmp_restore"
                    cp -rn "$TARGET_DIR/." "$SD.tmp_restore/" 2>/dev/null
                    rm -f "$SD"
                    mv "$SD.tmp_restore" "$SD"
                fi
            fi
        done
    done
    exit 0
fi

if [ "$AUTO_MIGRATE" == "true" ]; then
    migrate_once
    if [[ "$*" == *"--watch"* ]]; then
        echo "[migration] Background watcher active (Vivado). Scanning every 30s..."
        while true; do sleep 30; migrate_once; done
    fi
fi
