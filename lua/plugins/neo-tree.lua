return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    git_status_async = true,
    window = {
      mappings = {
        ["<space>"] = false, -- let leader key pass through
        ["e"] = "expand_all_subnodes",
        ["E"] = "expand_all_nodes",
      },
    },
  },
}
