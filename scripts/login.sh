#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"

# Login to Github, copilot and claude
gh auth login --with-token < ~/shared-common/github_readonly.pat
export COPILOT_GITHUB_TOKEN=`cat ~/shared-common/copilot.pat`
export CLAUDE_CODE_OAUTH_TOKEN=`cat ~/shared-common/claude.pat`

# Create a symlink so that .copilot is shared in the workspace folder
if [ ! -e "$HOME/.copilot" ]; then
    ln -s ~/workspace/.copilot "$HOME/.copilot"
fi

# Same deal for claude
if [ ! -e "$HOME/.claude" ]; then
    ln -s ~/workspace/.claude "$HOME/.claude"
fi
