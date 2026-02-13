local is_cloud_desktop = vim.env.NVIM_ENV == "cloud"

return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    if is_cloud_desktop then
      opts.sources = vim.tbl_filter(function(source) return source.name ~= "selene" end, opts.sources or {})
    end
  end,
}
