#!/bin/bash
set -e

# Clear any previous Xvfb lock
rm -f /tmp/.X${DISPLAY#:}*-lock

# Start Xvfb
Xvfb $DISPLAY -screen 0 ${RESOLUTION}x24 -ac &
#sleep 1

# Start Xfce
#startxfce4 &
sleep 1

# Start x11vnc
x11vnc -display $DISPLAY -nopw -forever -bg -xkb -q &
sleep 1

# Start noVNC / websockify
#websockify --web=/usr/share/novnc 6080 localhost:5900
# Start noVNC / websockify as PID 1
exec websockify --web=/usr/share/novnc 6080 localhost:5900
