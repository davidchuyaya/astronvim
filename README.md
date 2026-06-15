My IDE and terminal settings.

## Install

```shell
git clone https://github.com/davidchuyaya/astronvim ~/.config/nvim

# On Mac
./install_macos.sh
# On Linux
./install_linux.sh
# On Amazon Linux 2023
./install_amazon_linux.sh

# Install kitty if this is the machine that will SSH into others
# Then move the config
cp kitty.conf ~/.config/kitty/kitty.conf

# If remote & using tmux, copy tmux config
cp .tmux.conf ~/.tmux.conf

# Install all the AI clis I'm using these days
curl -fsSL https://antigravity.google/cli/install.sh | bash
curl https://cursor.com/install -fsS | bash
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

# Start each CLI and log in with credentials
gemini
agent
claude
codex
```
