# Isolated Development Environment (Podman)

## TL;DR
Make sure podman is installed and running and podman-compose is installed and in the path, then run the following commands:

- `podman-compose build`
- `alpha.bat` or `chmod +x ./alpha.sh && ./alpha.sh` to start the dev environment and connect to the alpha container

## Details

Allows you to create a set of dev environments using Podman compose.  Each container is described in `podman-compose.yml`, adding new ones is as simple as adding a new service to the file.

Currently only `dev-container-alpha` is defined, but you can add more by following the same pattern.

The dev environment has installed the following main tools:
- General dev tools including perf
- Rust toolchain (rustup, cargo, rustc)
- Python3
- Node
- Cargo flamegraph, uv, cargo-samply, samply, ripgrep

The dev environment will have two folders mounted from the host:
- `~/shared-common` - for files you want to share across all dev environments.  This contains credentials to login into GitHub and Copilot, but you can add other files here as well.
- `~/workspace-alpha` - for files you want to share only with the alpha dev environment.  This is where you would put project files for the alpha environment.

## Access Tokens
To access GitHub and Copilot from within the container, you will need to create a GitHub Personal Access Token (PAT) with the appropriate scopes.  The login script `login.sh` runs as part of the `.zshrc` and looks for these files:
- `~/shared-common/github_readonly.pat` - this should contain a GitHub PAT with read-only access to your repositories.
- `~/shared-common/copilot.pat` - this should contain a GitHub PAT with access to Copilot.
- `~/shared-common/claude.pat` - this should contain an OAT token with access to claude.

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

And for Claude
1. Run `claude setup-token` from cmdline
2. Paste the token into `storage/shared-common/claude.pat`

## Building and Running the Dev Environment

### Build
```bash
podman-compose build
```

If you modify the Dockerfile, you will need to rebuild the image with the --no-cache flag to ensure the changes are applied.

```bash
podman-compose build --no-cache
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

## General notes

### Enabling perf in WSL
To enable perf in WSL, you need to do the following:
1. Connect to the podman host: `podman machine ssh`
2. Add this line to the end of the `/etc/sysctl.d/99-sysctl.conf` file: `kernel.perf_event_paranoid=1`
3. Restart the podman machine: `podman machine stop && podman machine start`
