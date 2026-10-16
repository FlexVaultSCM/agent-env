#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"

# Login to Github and copilot. Claude is logged in interactively (/login); its state
# lives in ~/workspace/.claude via CLAUDE_CONFIG_DIR so it persists across rebuilds.
gh auth login --with-token < ~/shared-common/github_readonly.pat
export COPILOT_GITHUB_TOKEN=`cat ~/shared-common/copilot.pat`

# Create a symlink so that .copilot is shared in the workspace folder
if [ ! -e "$HOME/.copilot" ]; then
    ln -s ~/workspace/.copilot "$HOME/.copilot"
fi
