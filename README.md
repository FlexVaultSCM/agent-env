# Isolated Development Environment (Podman)

## TL;DR
Make sure podman is installed and running and podman-compose is installed and in the path, then:

**Windows (WSLg, includes GUI support):**
- `wslg-compose.bat build`
- `alpha.bat` to start the dev environment and connect to the alpha container

**macOS / Linux (headless):**
- `podman-compose build`
- `chmod +x ./alpha.sh && ./alpha.sh` to start the dev environment and connect to the alpha container

## Details

Allows you to create a set of dev environments using Podman compose.  Each container is described in `podman-compose.yml`, adding new ones is as simple as adding a new service to the file.

Currently only `dev-container-alpha` is defined, but you can add more by following the same pattern.  If a new container should have GUI access on Windows, also add an entry for it to `podman-compose.wslg.yml`.

The containers are deliberately locked down so agents can run largely unfettered without being able to change global/admin state: there is no `sudo`, all capabilities are dropped except a minimal set, `no-new-privileges` is set, and a seccomp profile is applied.

The dev environment has installed the following main tools:
- General dev tools including perf
- Rust toolchain (rustup, cargo, rustc)
- Python3, uv
- Node
- Cargo flamegraph, cargo-samply, samply, ripgrep
- GitHub CLI, Copilot CLI, Claude Code

The dev environment will have two folders mounted from the host:
- `~/shared-common` - for files you want to share across all dev environments.  This contains credentials to login into GitHub and Copilot, but you can add other files here as well.
- `~/workspace` - for files you want to share only with the alpha dev environment (`storage/workspace-alpha` on the host).  This is where you would put project files for the alpha environment.

## Platforms

The compose setup is split in two:
- `podman-compose.yml` - the cross-platform base.  Builds the `base` target of the Dockerfile.  Works on Windows, macOS and Linux.
- `podman-compose.wslg.yml` - a Windows-only overlay.  Builds the `desktop` target (base + GUI libraries) and connects the container to the WSLg X11 server.  `wslg-compose.bat` runs `podman-compose` with both files applied, and accepts the same arguments (`wslg-compose build`, `wslg-compose up -d`, ...).

On Windows, use `wslg-compose.bat` in place of `podman-compose` for all of the commands below.

### GUI apps (Windows only)
With the WSLg overlay, X11 apps run in the container appear as windows on the Windows desktop.  To check it works, run `xterm` from inside the container.

Claude Desktop is installed in the desktop image; run `claude-desktop` to start it.  This runs a launcher (`scripts/claude-desktop.sh`) that passes the Chromium flags needed in the container (`--no-sandbox`, `--password-store=gnome-libsecret`) and writes the app's (noisy) console output to `/tmp/runtime-devuser/claude-desktop.log`.

The desktop image starts a D-Bus session bus and an unlocked gnome-keyring when the container starts (`scripts/container-init.sh`), shared by everything in the container, so apps that store secrets (Claude Desktop, gh) can do so without prompting.  The keyring lives in the container, so the Claude Desktop sign-in lasts across container restarts, but not when the container is recreated.

Claude Desktop's own state (the Code tab's session list, Cowork sessions, scheduled tasks, MCP servers, preferences, and the files of "No folder" sessions) is kept in `~/workspace/.claude-desktop`: at container start, `scripts/claude-desktop-persist.sh` makes `~/.config/Claude` a symlink to it.  So after recreating the container you only need to sign in again; your sessions are still there.  The session transcripts themselves are in `~/workspace/.claude` (see [Claude](#claude)).

Other Electron apps will usually need to be started with `--no-sandbox` too, as Chromium's sandbox can't set itself up under `no-new-privileges` and the seccomp profile.  The container itself is the sandbox.

## Access Tokens
To access GitHub and Copilot from within the container, you will need to create a GitHub Personal Access Token (PAT) with the appropriate scopes.  The login script `login.sh` runs as part of the `.zshrc` and looks for these files:
- `~/shared-common/github_readonly.pat` - this should contain a GitHub PAT with read-only access to your repositories.
- `~/shared-common/copilot.pat` - this should contain a GitHub PAT with access to Copilot.

To create these PATs, follow these steps:

To get started, Go to GitHub and navigate to Settings > Developer settings > Personal access tokens.

To create a token with read-only access to repositories:
1. Click on "Generate new token"
2. (optional) If the repository you want to access belongs to an Organization, change the "Resource owner" to the Organization and not your personal account.
3. Select the appropriate scopes for your use case.  For read-only access to repositories, under Permissions select the repository you want to allow access to, then check "Contents" as the permission with "Access" set to "Read-only". 
4. Generate the token and copy it to a secure location.  Then create the `github_readonly.pat` file in the `storage/shared-common` directory and paste the token there.

To create a token with access to Copilot:
1. Click on "Generate new token"
2. Select the appropriate scopes for your use case.  For Copilot access, under Permissions select "Copilot Chat", "Copilot Editor Context" and "Copilot Requests".
3. Generate the token and copy it to a secure location.  Then create the `copilot.pat` file in the `storage/shared-common` directory and paste the token there.

### Claude
Run `claude` in the container and log in with `/login`.  All Claude Code state (credentials, settings, history) is kept in `~/workspace/.claude` via `CLAUDE_CONFIG_DIR`, so the login survives rebuilding the image or recreating the container.

## Building and Running the Dev Environment

### Build
```bash
podman-compose build
```

Layer caching means changes to the Dockerfile only rebuild from the changed step onwards, so `--no-cache` is not needed after editing the Dockerfile.

A normal build also picks up new Claude Desktop releases (desktop image): the build downloads the apt repository's package index, and the install step re-runs whenever that changes.  Claude Desktop can't be updated with `apt` from inside the container, as there's no root access there.

To pull newer versions of everything else (Rust nightly, Claude Code, Debian packages, etc.), use `--no-cache`:

```bash
podman-compose build --no-cache
```

A rebuilt image is only picked up when the container is recreated; `up -d` (and so `alpha.bat`) keeps an existing container.  Recreating discards anything in the container outside the mounted folders:

```bash
podman-compose up -d --force-recreate
```

### Run the swarm
The `-d` is for detached.

```bash
podman-compose up -d
```

### Connect to a container
```bash
podman exec -it dev-container-alpha zsh
```

### Connect to a container in VSCode
Ensure the _Dev Containers_ extension is installed, then open the command palette and select "Remote-Containers: Attach to Running Container..." and select the container you want to connect to. 

## Disk usage
Anything written inside the container outside of the mounted folders lives in the container's writable layer, which is stored on the podman machine's disk.  That disk grows but never shrinks on its own, so:
- `/tmp` is a tmpfs capped at 8GB, and is cleared on every container restart.  This includes Claude Code's scratch files (`/tmp/claude-1000`), which previously grew to 60GB; if it fills up, restart the container.
- Put large data sets (symbols, downloads, build outputs) under `~/workspace`, not elsewhere in the home directory.

To see what's using space: `podman system df` and `podman ps -a --size`.

## General notes

### Enabling perf
To enable perf in the containers, you need to do the following on the podman machine (WSL or macOS):
1. Connect to the podman host: `podman machine ssh`
2. Add this line to the end of the `/etc/sysctl.d/99-sysctl.conf` file: `kernel.perf_event_paranoid=1`
3. Restart the podman machine: `podman machine stop && podman machine start`

This needs to be redone whenever the podman machine is recreated.
