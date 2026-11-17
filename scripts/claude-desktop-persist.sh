#!/bin/sh
# Keeps Claude Desktop's own state in the workspace mount, so it survives recreating the container.
# Run by container-init.sh at container start, before Claude Desktop can be launched. Installed as
# /usr/local/bin/claude-desktop-persist in the desktop image.
#
# Claude Desktop keeps its data in ~/.config/Claude, separately from Claude Code's CLAUDE_CONFIG_DIR.
# This covers the Code tab's session list (titles, folders, links to the transcripts kept in
# ~/workspace/.claude), Cowork sessions, scheduled tasks, MCP servers and preferences, and the files
# of "No folder" sessions. ~/.config/Claude is made a symlink into the workspace, the same way as
# ~/.copilot. A bind mount isn't used because podman would create a missing ~/.config owned by root.
#
# The sign-in is not kept: Chromium encrypts it with a key held in the container's gnome-keyring,
# which is recreated with the container, so the app asks you to sign in again.
#
# Only run it while Claude Desktop is not running. To move an existing container's data over by
# hand, quit Claude Desktop first, then run: sh ~/workspace/agent-env/scripts/claude-desktop-persist.sh
live="$HOME/.config/Claude"
kept="$HOME/workspace/.claude-desktop"

mkdir -p "$kept" "$HOME/.config"

# Data from before this script existed is in the container itself: move it into the workspace.
# If the copy fails, the directory is left alone and the app keeps working, just without persisting.
if [ -d "$live" ] && [ ! -L "$live" ]; then
    cp -R "$live/." "$kept/" && rm -rf "$live"
fi
if [ ! -e "$live" ] && [ ! -L "$live" ]; then
    ln -s "$kept" "$live"
fi

# Chromium's single-instance lock records the hostname, which is the container ID. A lock left by
# an old container looks like the profile is in use on another machine, and the app won't start.
rm -f "$kept/SingletonLock" "$kept/SingletonSocket" "$kept/SingletonCookie"
