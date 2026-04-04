#!/bin/bash
set -e

# Clear any previous Xvfb lock
rm -f /tmp/.X${DISPLAY#:}*-lock

# Ensure system paths have correct permissions for the guest user
mkdir -p /tmp/.ICE-unix /tmp/.X11-unix
chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix

# Ensure the Docker socket is accessible to our user
if [ -e /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# Initialize DBus machine-id
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure

# Re-align guest home permissions
echo "[display] Aligning guest permissions..."
chown -R guest:guest /home/guest

# Prepare the dynamic Desktop volume (shared with tool containers)
mkdir -p /tmp/shared-desktop
chmod 1777 /tmp/shared-desktop

# Symlink guest desktop to shared volume to show icons instantly
rm -rf /home/guest/Desktop
ln -sf /tmp/shared-desktop /home/guest/Desktop
chown -h guest:guest /home/guest/Desktop

# Start Xvfb (as root)
Xvfb $DISPLAY -screen 0 ${RESOLUTION}x24 -ac &
sleep 1

# Start x11vnc (as root)
x11vnc -display $DISPLAY -nopw -forever -bg -xkb -q &
sleep 1

# Start Xfce desktop session as GUEST
echo "[display] Starting stable XFCE session..."
export XDG_RUNTIME_DIR=/tmp/runtime-guest
mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR && chown guest:guest $XDG_RUNTIME_DIR

sudo -u guest bash -c "export DISPLAY=$DISPLAY; export XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR; \
    dbus-run-session -- bash -c 'xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s \"Humanity\" || true; startxfce4'" > /proc/1/fd/1 2>&1 &
sleep 3

# Start noVNC / websockify as PID 1
exec websockify --web=/usr/share/novnc 6080 localhost:5900
