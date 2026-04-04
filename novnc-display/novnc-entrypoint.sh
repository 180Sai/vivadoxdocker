#!/bin/bash
# novnc-display/novnc-entrypoint.sh — Xvfb/VNC stack setup
set -e

# Clear any previous Xvfb lock
rm -f /tmp/.X${DISPLAY#:}*-lock

# Ensure system paths have correct permissions for the guest user
mkdir -p /tmp/.ICE-unix /tmp/.X11-unix
chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix

# Ensure the Docker socket is accessible to our user
if [ -e /var/run/docker.sock ]; then
    chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# Initialize DBus machine-id
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure

# Re-align guest home permissions
echo "[display] Aligning guest permissions..."
chown -R guest:guest /home/guest

# Prepare the dynamic Desktop volume
mkdir -p /tmp/shared-desktop
chmod 1777 /tmp/shared-desktop

# Symlink guest desktop to shared volume
rm -rf /home/guest/Desktop
ln -sf /tmp/shared-desktop /home/guest/Desktop
chown -h guest:guest /home/guest/Desktop

# Session setup
export XDG_RUNTIME_DIR=/tmp/runtime-guest
mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR && chown guest:guest $XDG_RUNTIME_DIR

# ─── Process Supervision ───────────────────────────────────────────────────
# Hands off control to runit (runsvdir) to manage X, VNC, and Desktop sessions
exec /usr/bin/runsvdir -P /etc/service
