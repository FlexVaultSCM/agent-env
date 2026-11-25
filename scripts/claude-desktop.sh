#!/bin/sh
# Launches Claude Desktop inside the container. Installed as /usr/local/bin/claude-desktop so it
# takes precedence over the packaged /usr/bin/claude-desktop.
#
# The D-Bus session and unlocked keyring the app needs to save its sign-in are started with the
# container (see container-init.sh). On top of that:
# - --password-store=gnome-libsecret: Chromium only picks the keyring automatically when it
#   recognises the desktop environment, otherwise it falls back to plain text and Electron reports
#   safeStorage as unavailable.
# - --no-sandbox: Chromium's sandbox can't set itself up under no-new-privileges + seccomp.
# - Chromium logs a lot of harmless noise (no system bus, no GPU), so send it to a log file.
# - Start it detached in its own session, so the shell gets its prompt back straight away and
#   closing the shell doesn't take the app with it.
#
# Before starting the app, wait for claude-desktop-persist to finish, and check that the app can save
# its state. The app reports a failed save only in its log, so the check is here where it is seen.
LOG="${XDG_RUNTIME_DIR:-/tmp}/claude-desktop.log"
STATE="$HOME/.config/Claude"

waited=0
while [ ! -e "$XDG_RUNTIME_DIR/claude-desktop-ready" ] && [ "$waited" -lt 120 ]; do
    [ "$waited" -eq 0 ] && echo "Waiting for Claude Desktop's state to be prepared..."
    sleep 1
    waited=$((waited + 1))
done

mkdir -p "$STATE"
if ! chmod 700 "$STATE" 2>/dev/null || ! [ -O "$STATE" ]; then
    echo "WARNING: Claude Desktop can't set permissions on $STATE, so its sessions will not be saved." >&2
    echo "Check that the claude-desktop-alpha volume is mounted there (see the agent-env README)." >&2
elif ! grep -q " $STATE " /proc/mounts; then
    echo "WARNING: $STATE is not on a volume, so its sessions will be lost when the container is recreated." >&2
fi

echo "Claude Desktop started, output is logged to $LOG"

setsid -f /usr/bin/claude-desktop --no-sandbox --password-store=gnome-libsecret "$@" >>"$LOG" 2>&1 </dev/null
