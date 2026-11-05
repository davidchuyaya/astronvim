-- Keep inline commands and environments, but hide large TeX scaffolds from completion.
local large_snippets = setmetatable({}, { __mode = "k" })

local function is_large_snippet(snippet)
  if large_snippets[snippet] ~= nil then return large_snippets[snippet] end

  -- Blink's LuaSnip items contain the trigger, not the expansion body.
  local ok, body = pcall(snippet.get_docstring, snippet)
  if not ok then return false end
  if type(body) == "table" then body = table.concat(body, "\n") end
  if type(body) ~= "string" then return false end

  local _, newlines = body:gsub("\n", "")
  local document = body:find("\\documentclass", 1, true) and body:find("\\begin{document}", 1, true)
  local large = document ~= nil or newlines + 1 > 25 or #body > 1500
  large_snippets[snippet] = large
  return large
end

return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}
      local snippets = opts.sources.providers.snippets or {}
      opts.sources.providers.snippets = snippets
      local previous_transform = snippets.transform_items
      local environments = require "latex-environments"
      snippets.override = snippets.override or {}
      local previous_completions = snippets.override.get_completions
      snippets.override.get_completions = function(source, ctx, callback)
        return environments.completions(source, ctx, callback, previous_completions)
      end
      local previous_execute = snippets.override.execute
      local previous_resolve = snippets.override.resolve
      snippets.override.resolve = function(source, item, callback)
        if item.data and item.data.latex_end_environment then return callback(item) end
        if previous_resolve then return previous_resolve(source, item, callback) end
        return source:resolve(item, callback)
      end
      snippets.override.execute = function(source, ctx, item, callback, default)
        return environments.execute(source, ctx, item, callback, default, previous_execute)
      end

      snippets.transform_items = function(ctx, items)
        if previous_transform then items = previous_transform(ctx, items) end
        local ft = vim.bo[ctx.bufnr].filetype
        if ft ~= "tex" and ft ~= "plaintex" then return items end

        local ok, luasnip = pcall(require, "luasnip")
        if not ok then return items end
        items = vim.tbl_filter(function(item)
          local id = type(item.data) == "table" and item.data.snip_id
          if not id then return true end
          local found, snippet = pcall(luasnip.get_id_snippet, id)
          -- Unknown/custom items stay available rather than breaking completion.
          return not found or not snippet or not is_large_snippet(snippet)
        end, items)
        return environments.items(ctx, items, luasnip)
      end
    end,
  },
}
