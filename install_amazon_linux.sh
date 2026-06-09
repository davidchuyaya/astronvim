#!/bin/bash

# Install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
# Add to path
echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc

# Install ripgrep
curl -LO https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz
tar -xzf ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz
sudo mv ripgrep-15.1.0-x86_64-unknown-linux-musl/rg /usr/local/bin
rm -rf ripgrep-15.1.0-x86_64-unknown-linux-musl
rm ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz

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
