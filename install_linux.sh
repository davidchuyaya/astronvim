#!/bin/bash
sudo apt-get update

# Install necessary packages
sudo apt-get install -y build-essentials unzip ripgrep neovim

# Install tree-sitter-cli
curl -LO https://github.com/tree-sitter/tree-sitter/releases/download/v0.26.9/tree-sitter-cli-linux-x86.zip
unzip tree-sitter-cli-linux-x86.zip
sudo mv tree-sitter /usr/local/bin

# Install node for toggleterminal
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"
# Download and install Node.js:
nvm install 24
