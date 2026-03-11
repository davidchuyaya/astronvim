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
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = function() return { vim.fn.getreg("", 1, true), vim.fn.getregtype("") } end,
    ["*"] = function() return { vim.fn.getreg("", 1, true), vim.fn.getregtype("") } end,
  },
}
vim.opt.clipboard = "unnamedplus"
