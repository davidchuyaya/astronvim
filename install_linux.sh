#!/bin/bash
sudo apt-get update

# Install necessary packages
sudo apt-get install -y build-essentials unzip ripgrep neovim

# Install node for toggleterminal
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"
# Download and install Node.js:
nvm install 24
