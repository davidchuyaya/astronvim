-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

local is_personal = vim.env.NVIM_ENV == "personal"
---
---
---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- Inline code-completion using Amazon Q, if not on my personal computer
  -- Make sure to sign in with ":AmazonQ login" first
  -- Ghost text is handled by amazonq-ghost.lua (not blink.cmp)
  {
    "awslabs/amazonq.nvim",
    enabled = not is_personal,
    opts = {
      ssoStartUrl = "https://amzn.awsapps.com/start",
      inline_suggest = false, -- disable LSP shim so blink stays fast
    },
    config = function(_, opts)
      require("amazonq").setup(opts)
      require("amazonq-ghost").setup()
    end,
    specs = {
      {
        "AstroNvim/astrocore",
        opts = {
          options = {
            g = {
              ai_accept = function()
                local ghost = require("amazonq-ghost")
                if ghost.is_visible() then
                  ghost.accept()
                  return true
                end
              end,
            },
          },
        },
      },
    },
  },

  -- Inline code-completion using GitHub Copilot on my personal computer
  {
    "zbirenbaum/copilot.lua",
    enabled = is_personal,
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "BufReadPost",
    opts = {
      suggestion = {
        auto_trigger = true,
        keymap = {
          accept = false, -- handled by completion engine
        },
      },
    },
    specs = {
      {
        "AstroNvim/astrocore",
        opts = {
          options = {
            g = {
              -- set the ai_accept function
              ai_accept = function()
                if require("copilot.suggestion").is_visible() then
                  require("copilot.suggestion").accept()
                  return true
                end
              end,
            },
          },
        },
      },
    },
  },

  -- Autosave
  {
    "pocco81/auto-save.nvim",
  },

  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  {
    "akinsho/toggleterm.nvim",
    opts = {
      size = 50,
    },
  },

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<D-CR>"] = { "select_and_accept" },
      },
    },
  },

  {
    "windwp/nvim-autopairs",
    enabled = false,
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {
      on_attach = function(bufnr)
        local gs = require "gitsigns"
        local map = function(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc }) end
        map("n", "]h", gs.next_hunk, "Next hunk")
        map("n", "[h", gs.prev_hunk, "Prev hunk")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>gR", gs.reset_buffer, "Reset buffer")
        map("n", "<leader>gd", gs.diffthis, "Diff this")
      end,
    },
  },

  {
    "folke/sidekick.nvim",
    opts = {
      nes = { enabled = false },
      cli = {
        win = {
          split = { width = math.floor(vim.o.columns * 0.3) },
        },
        tools = {
          [is_personal and "gemini" or "kiro"] = {
            cmd = is_personal and { "gemini", "--yolo", "--no-status" } or { "kiro-cli", "chat", "--trust-all-tools" },
          },
        },
      },
    },
    keys = {
      {
        "<c-.>",
        function() require("sidekick.cli").toggle() end,
        desc = "Sidekick Toggle",
        mode = { "n", "t", "i", "x" },
      },
      {
        "<leader>aa",
        function() require("sidekick.cli").toggle { name = is_personal and "gemini" or "kiro", focus = true } end,
        desc = "Sidekick Toggle Kiro",
      },
      {
        "<leader>as",
        function() require("sidekick.cli").select() end,
        desc = "Select CLI",
      },
      {
        "<leader>ad",
        function() require("sidekick.cli").close() end,
        desc = "Detach CLI Session",
      },
      {
        "<leader>at",
        function() require("sidekick.cli").send { msg = "Current line: {this}" } end,
        mode = { "x", "n" },
        desc = "Send This",
      },
      {
        "<leader>af",
        function() require("sidekick.cli").send { msg = "Current file: {file}" } end,
        desc = "Send File",
      },
      {
        "<leader>av",
        function() require("sidekick.cli").send { msg = "Current selection: {selection}" } end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
      {
        "<leader>ap",
        function() require("sidekick.cli").prompt() end,
        mode = { "n", "x" },
        desc = "Sidekick Select Prompt",
      },
    },
  },
}
