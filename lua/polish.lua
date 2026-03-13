-- This will run last in the setup process.
vim.lsp.set_log_level("WARN")

-- Disable automatic comment wrapping
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove("c")
  end,
})

-- OSC 52: yank to local clipboard over SSH
local osc52 = require "vim.ui.clipboard.osc52"
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52.copy "+",
    ["*"] = osc52.copy "*",
  },
  paste = {
    ["+"] = osc52.paste "+",
    ["*"] = osc52.paste "*",
  },
}
vim.opt.clipboard = "unnamedplus"
