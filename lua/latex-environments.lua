-- Reuse installed LuaSnip environment snippets inside \begin{...} or beginNAME.
local M = {}
local environments = setmetatable({}, { __mode = "k" })

function M.completions(source, ctx, callback, previous)
  local function receive(result)
    local ft = vim.bo[ctx.bufnr].filetype
    if result and (ft == "tex" or ft == "plaintex") and (not ctx.mode or ctx.mode == "default") then
      -- Blink otherwise reuses the items transformed at the first keystroke
      -- (e.g. "b") without re-running our context-dependent transformation.
      -- LuaSnip still caches the snippet definitions; only local filtering is
      -- repeated, with no LSP or Overleaf request.
      result = vim.tbl_extend("force", {}, result, {
        is_incomplete_forward = true,
        is_incomplete_backward = true,
      })
    end
    callback(result)
  end
  if previous then return previous(source, ctx, receive) end
  return source:get_completions(ctx, receive)
end

function M.name(snippet)
  if environments[snippet] ~= nil then return environments[snippet] or nil end
  local ok, body = pcall(snippet.get_docstring, snippet)
  if not ok then return end
  if type(body) == "table" then body = table.concat(body, "\n") end
  local name = type(body) == "string" and body:match "^\\+begin{([^{}%s$]+)}"
  if not name or not body:find("\\end{" .. name .. "}", 1, true) then name = nil end
  environments[snippet] = name or false
  return name
end

function M.region(ctx, current)
  local ft = vim.bo[ctx.bufnr].filetype
  if (ft ~= "tex" and ft ~= "plaintex") or (ctx.mode and ctx.mode ~= "default") then return end
  local line = current and ctx.get_line() or ctx.line
  local cursor = current and ctx.get_cursor() or ctx.cursor
  local prefix = line:sub(1, cursor[2])
  -- Ignore comments, except an escaped \%.
  for pos = 1, #prefix do
    if prefix:sub(pos, pos) == "%" then
      local backslashes = prefix:sub(1, pos - 1):match "(\\*)$"
      if #backslashes % 2 == 0 then return end
    end
  end
  local start = prefix:find "%f[%w_]begin%s*{[^{}%s]*$"
  local compact = not start
  if compact then start = prefix:find "%f[%w_]begin[%w@*:_%-]*$" end
  if not start then return end
  if prefix:sub(start - 1, start - 1) == "\\" then start = start - 1 end
  local backslashes = prefix:sub(1, start - 1):match "(\\*)$"
  if #backslashes % 2 ~= 0 then return end
  -- Replace the command as well as the partial name and any existing brace.
  local suffix = line:sub(cursor[2] + 1):match "^[%w@*:_%-]*}?" or ""
  return {
    from = { cursor[1] - 1, start - 1 },
    to = { cursor[1] - 1, cursor[2] + #suffix },
    filter_prefix = compact and "begin" or "",
  }
end

function M.items(ctx, items, luasnip)
  local region = M.region(ctx)
  if not region then return require("latex-end-environment").items(ctx, items) end
  local result, seen = {}, {}
  for _, item in ipairs(items) do
    local id = type(item.data) == "table" and item.data.snip_id
    local ok, snippet = pcall(luasnip.get_id_snippet, id)
    local name = ok and snippet and M.name(snippet)
    if name then
      item = vim.deepcopy(item)
      item.label, item.filterText = name, region.filter_prefix .. name
      -- Prefer the expansion over TexLab's name-only completion, but keep
      -- normal fuzzy matching/ranking between the environment snippets.
      item.score_offset = math.max(item.score_offset or 0, 1000)
      item.data.latex_environment = true
      item.textEdit = {
        newText = "\\begin{" .. name .. "}",
        range = {
          start = { line = region.from[1], character = region.from[2] },
          ["end"] = { line = region.to[1], character = region.to[2] },
        },
      }
      if not seen[name] then
        result[#result + 1], seen[name] = item, #result + 1
      elseif snippet.trigger == name then
        result[seen[name]] = item
      end
    end
  end
  return result
end

function M.execute(source, ctx, item, callback, default, previous)
  if require("latex-end-environment").execute(ctx, item, callback) then return end
  if item.data and item.data.latex_environment then
    -- Recalculate after Blink undoes its completion preview; never clear only
    -- "enu", which would leave a duplicate \begin before the expansion.
    local region = M.region(ctx, true)
    if region then
      local luasnip = require "luasnip"
      local snippet = luasnip.get_id_snippet(item.data.snip_id)
      luasnip.snip_expand(snippet, { clear_region = region })
      if callback then callback() end
      return
    end
  end
  if previous then return previous(source, ctx, item, callback, default) end
  return source:execute(ctx, item, callback, default)
end

return M
