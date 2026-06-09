return {
  "mrcjkb/rustaceanvim",
  keys = {
    { "<Leader>lt", function() vim.cmd.RustLsp("testables") end, desc = "Rust Testables" },
  },
  opts = function()
    local astrolsp_avail, astrolsp = pcall(require, "astrolsp")
    local astrolsp_opts = astrolsp_avail and astrolsp.lsp_opts("rust_analyzer") or {}

    local server = {
      on_attach = function(client, bufnr)
        if astrolsp_avail then
          astrolsp.on_attach(client, bufnr)
        end
      end,
    }

    return {
      server = require("astrocore").extend_tbl(astrolsp_opts, server),
      tools = {
        -- Allow running tests with reserved bash characters (like <Type>)
        test_executor = {
          execute_command = function(cmd, args, cwd, opts)
            local escaped_args = vim.tbl_map(vim.fn.shellescape, args)
            require("rustaceanvim.executors.termopen").execute_command(cmd, escaped_args, cwd, opts)
          end,
        },
      },
    }
  end,
}
