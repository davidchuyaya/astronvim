-- This will run last in the setup process.
vim.lsp.set_log_level("WARN")

-- Disable automatic comment wrapping
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove("c")
  end,
})
