return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      mappings = {
        ["<space>"] = false, -- let leader key pass through
        ["e"] = "expand_all_subnodes",
        ["E"] = "expand_all_nodes",
      },
    },
  },
}
