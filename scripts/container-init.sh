#!/bin/sh
# Container start-up (the image's CMD).
#
# Creates the private runtime dir on the /tmp tmpfs. In the desktop image it also starts a D-Bus
# session bus and an unlocked gnome-keyring, shared by everything in the container (shells, gh,
# Claude Desktop), as a desktop login session would. Without this, any keyring user (e.g. gh in
# login.sh) auto-launches its own bus and keyring daemon, which then prompts for the password.
mkdir -p -m 700 "$XDG_RUNTIME_DIR"

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-daemon >/dev/null && command -v gnome-keyring-daemon >/dev/null; then
    dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --fork --nopidfile
    # gnome-keyring needs a non-empty password to create the default "login" keyring; a fixed one
    # is fine as the container is the security boundary.
    printf "devuser" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
fi

exec sleep infinity
