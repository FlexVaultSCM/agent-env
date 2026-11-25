#!/bin/sh
# Prepares ~/.config/Claude, where Claude Desktop keeps its own state, before the app can be
# launched. Run by container-init.sh at container start. Installed as
# /usr/local/bin/claude-desktop-persist in the desktop image.
#
# ~/.config/Claude is a named volume (see podman-compose.wslg.yml), so it survives recreating the
# container. It can't be kept in ~/workspace: the app sets permissions on its directories before
# each save, and ~/workspace refuses chmod, so every save fails and the session list is lost when
# the app closes.
#
# Earlier versions kept it in ~/workspace/.claude-desktop. That is copied into the volume once, when
# the volume is empty, and is then left alone.
live="$HOME/.config/Claude"
old="$HOME/workspace/.claude-desktop"
copying="$live/.migrating"    # copy in progress: discarded and started again if interrupted
copied="$live/.migrated"      # copy complete, waiting to be moved into place

migrate() {
    rm -rf "$copying"
    mkdir "$copying" || return 1
    for entry in "$old"/* "$old"/.[!.]*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        case "${entry##*/}" in
            # Caches, the bundled Claude Code, and locks: the app creates these again
            Cache | "Code Cache" | GPUCache | GPUPersistentCache | DawnGraphiteCache | DawnWebGPUCache) continue ;;
            claude-code | claude-code-spare | git-shadow | Singleton*) continue ;;
        esac
        cp -R "$entry" "$copying/" || return 1
    done
    # Everything in ~/workspace has mode 777
    chmod -R go= "$copying" && mv "$copying" "$copied"
}

if [ -d "$live" ] && [ ! -L "$live" ]; then
    if [ -d "$old" ] && [ -z "$(ls -A "$live" | grep -vx '\.migrating')" ]; then
        migrate || echo "claude-desktop-persist: could not copy $old into $live" >&2
    fi
    if [ -d "$copied" ]; then
        find "$copied" -mindepth 1 -maxdepth 1 -exec mv -n -t "$live" {} + && rmdir "$copied"
    fi

    # Chromium's single-instance lock records the hostname, which is the container ID. A lock left
    # by an old container looks like the profile is in use on another machine, and the app won't
    # start.
    rm -f "$live/SingletonLock" "$live/SingletonSocket" "$live/SingletonCookie"
fi

# The launcher (claude-desktop.sh) waits for this, so the app never starts partway through a copy.
# It is on the /tmp tmpfs, so it is cleared on every container restart.
touch "$XDG_RUNTIME_DIR/claude-desktop-ready"
