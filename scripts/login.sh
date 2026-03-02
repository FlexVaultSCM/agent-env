#!/bin/bash
export PATH="$HOME/.local/bin:$PATH"
gh auth login --with-token < ~/shared-common/github_readonly.pat
export COPILOT_GITHUB_TOKEN=`cat ~/shared-common/copilot.pat`
