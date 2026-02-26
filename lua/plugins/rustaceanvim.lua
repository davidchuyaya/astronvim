return {
  "mrcjkb/rustaceanvim",
  keys = {
    { "<Leader>lt", function() vim.cmd.RustLsp("testables") end, desc = "Rust Testables" },
  },
  opts = {
    tools = {
      -- Allow running tests with reserved bash characters (like <Type>)
      test_executor = {
        execute_command = function(cmd, args, cwd, opts)
          local escaped_args = vim.tbl_map(vim.fn.shellescape, args)
          require("rustaceanvim.executors.termopen").execute_command(cmd, escaped_args, cwd, opts)
        end,
      },
    },
  },
}
