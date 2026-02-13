-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- Chat using kiro
  {
    "olimorris/codecompanion.nvim",
    version = "^18.0.0",
    opts = {
      adapters = {
        kiro = function()
          return require("codecompanion.adapters").extend("kiro", {
            commands = {
              default = {
                "kiro-cli",
                "acp",
                "--trust-all-tools",
              },
            },
          })
        end,
      },
      display = {
        chat = {
          window = {
            width = 0.3,
          },
          auto_scroll = true,
        },
      },
      interactions = {
        chat = {
          adapter = "kiro",
          keymaps = {
            send = {
              modes = { n = "<D-CR>", i = "<D-CR>" },
              opts = {},
            },
          },
          tools = {
            ["cmd_runner"] = {
              opts = {
                allowed_in_yolo_mode = true,
              },
            },
          },
        },
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
  },

  -- Inline code-completion using Amazon Q
  -- Make sure to sign in with ":AmazonQ login" first
  {
    "awslabs/amazonq.nvim",
    opts = {
      ssoStartUrl = "https://amzn.awsapps.com/start",
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
    "windwp/nvim-autopairs",
    enabled = false,
  },
}
