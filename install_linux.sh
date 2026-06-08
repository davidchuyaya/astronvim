#!/bin/bash
sudo apt-get update

# Install ripgrep and neovim
sudo apt-get install ripgrep neovim

# Install node for toggleterminal
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"
# Download and install Node.js:
nvm install 24
