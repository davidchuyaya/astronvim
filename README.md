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

## LaTeX completion

Argument completions immediately before an existing `}` query the original
document rather than a prefix-only temporary copy. This keeps included chapters
connected to the main document's bibliography, so `\cite{paxos,|}` offers keys
from `refs.bib`. Prefix-only copies are still used when there is actual token
text after the cursor to exclude.

The TeX snippet completion filter in `lua/plugins/latex-snippets.lua` hides whole-document
templates and expansions longer than 25 lines or 1,500 characters. Small command and
environment snippets (including `emph` and `enumerate`) remain available, as do LSP
completions for citations and labels. This filters expansion bodies rather than maintaining
a blacklist of snippet names, and does not affect other filetypes.

Environment snippets also appear while typing names inside `\begin{...}`. For
example, type `\begin{enu`, select the `enumerate` snippet (marked `~`), and accept
it to insert the matching `\end{enumerate}` and first `\item`, with the cursor
ready to type the item. This reuses the installed LuaSnip snippets; TexLab's
plain environment-name completions remain available too.
You can also type `beginenu` or `\beginenu` without braces. In these contexts,
environment snippets are ranked above plain-name completions, so Enter accepts
the full expansion without first navigating to the snippet.

TexLab suggestions are queried using only text before the cursor on the current
line, even when more text follows (for example `$\G|hello$`). Neovim sends a
temporary in-memory document to the local TexLab process, retaining the rest of
the document. It maps the returned edits back and closes
the temporary document; no file is created and neither the real buffer nor its
LSP document is temporarily edited. This works for ordinary TeX files as well as
Overleaf mirrors, with no Overleaf requests or extra symbol plugin.

Following text is preserved when accepting. If letters immediately follow a TeX
command, an empty group separates them: accepting `Gamma` in `$\G|hello$` produces
`$\Gamma{}hello$`, rather than changing the command into `\Gammahello`.

Typing `\en`, `\end`, or `\end{...` offers a high-priority completion for the
nearest open environment that has no matching closer later in the live buffer.
Nested environments are matched in order; comments, inline verbatim examples and
verbatim blocks do not create false matches. Accepting inserts only the closing
`\end{...}` and preserves following text. This is local and works without TexLab.
