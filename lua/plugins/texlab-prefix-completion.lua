return {
  {
    "AstroNvim/astrocore",
    init = function() require("texlab-prefix-completion").setup() end,
  },
  {
    "saghen/blink.cmp",
    opts = { completion = { keyword = { range = "prefix" } } },
  },
}
