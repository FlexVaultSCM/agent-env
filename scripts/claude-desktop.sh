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
LOG="${XDG_RUNTIME_DIR:-/tmp}/claude-desktop.log"
echo "Claude Desktop started, output is logged to $LOG"

setsid -f /usr/bin/claude-desktop --no-sandbox --password-store=gnome-libsecret "$@" >>"$LOG" 2>&1 </dev/null
