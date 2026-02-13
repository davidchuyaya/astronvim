return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    window = {
      mappings = {
        nowait = false,
        ["e"] = "expand_all_subnodes",
        ["E"] = "expand_all_nodes",
      },
    },
  },
}
