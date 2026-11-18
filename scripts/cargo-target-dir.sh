#!/bin/sh
# Installed as ~/.local/bin/cargo, ahead of rustup's cargo on PATH.
#
# ~/workspace is a host bind mount that refuses chmod, so build scripts that copy files and set
# their permissions (zstd-sys, aws-lc-sys) fail in a project's own target directory with
# "Operation not permitted". For a project under ~/workspace this runs cargo with CARGO_TARGET_DIR
# set to ~/.cache/cargo-target/<the project's path under ~/workspace, with / replaced by ->, so
# each checkout has its own build directory. An existing CARGO_TARGET_DIR is left as it is, and
# projects outside ~/workspace build where cargo would build them.
real_cargo="$HOME/.cargo/bin/cargo"

if [ -z "$CARGO_TARGET_DIR" ]; then
    manifest=$("$real_cargo" locate-project --workspace --message-format plain 2>/dev/null)
    case "$manifest" in
        "$HOME/workspace/"*)
            project=$(dirname "$manifest")
            name=$(printf '%s' "${project#"$HOME/workspace/"}" | tr '/' '-')
            CARGO_TARGET_DIR="$HOME/.cache/cargo-target/$name"
            export CARGO_TARGET_DIR
            ;;
    esac
fi

exec "$real_cargo" "$@"
