-- Complete only an unmatched environment, using the live buffer (no LSP/API).
local M = {}
local verbatim =
  { verbatim = true, ["verbatim*"] = true, Verbatim = true, lstlisting = true, minted = true, comment = true }

local function escaped(text, pos)
  local count = 0
  while pos > 1 and text:sub(pos - 1, pos - 1) == "\\" do
    pos, count = pos - 1, count + 1
  end
  return count % 2 == 1
end

local function clean(line)
  line = line:gsub("(\\verb%*?([^%a%s]).-%2)", function(match) return string.rep(" ", #match) end)
  for pos = 1, #line do
    if line:sub(pos, pos) == "%" and not escaped(line, pos) then
      line = line:sub(1, pos - 1) .. string.rep(" ", #line - pos + 1)
      break
    end
  end
  return line
end

function M.item(ctx, current)
  local ft = vim.bo[ctx.bufnr].filetype
  if (ft ~= "tex" and ft ~= "plaintex") or (ctx.mode and ctx.mode ~= "default") then return end
  local line = current and ctx.get_line() or ctx.line
  local cursor = current and ctx.get_cursor() or ctx.cursor
  local prefix = clean(line:sub(1, cursor[2]))
  local start = prefix:find "\\end%s*{[^{}%s]*$"
  local braces = start ~= nil
  if not start then start = prefix:find "\\end?$" end
  if not start or escaped(prefix, start) then return end
  local finish = cursor[2]
  if braces and line:sub(finish + 1, finish + 1) == "}" then finish = finish + 1 end
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
  local cutoff = 0
  for row, text in ipairs(lines) do
    lines[row] = clean(text)
    if row < cursor[1] then cutoff = cutoff + #text + 1 end
  end
  -- The partially typed closer is the completion target, not an existing end.
  lines[cursor[1]] = lines[cursor[1]]:sub(1, start - 1)
    .. string.rep(" ", finish - start + 1)
    .. lines[cursor[1]]:sub(finish + 1)
  cutoff = cutoff + cursor[2]
  local text, stack, active, blocked, position = table.concat(lines, "\n"), {}, nil, nil, 1
  while true do
    local first, last, kind, name = text:find("\\([%a]+)%s*{%s*([^{}%s]+)%s*}", position)
    if not first then break end
    position = last + 1
    if not escaped(text, first) and (kind == "begin" or kind == "end") then
      if first > cutoff and active == nil then
        active = stack[#stack] or false
        if blocked then return end
      end
      if not blocked or (kind == "end" and name == blocked) then
        if kind == "begin" then
          stack[#stack + 1] = { name = name }
          if verbatim[name] then blocked = name end
        elseif stack[#stack] and stack[#stack].name == name then
          stack[#stack].closed = true
          table.remove(stack)
          blocked = nil
        end
      end
    end
  end
  if active == nil then
    if blocked then return end
    active = stack[#stack]
  end
  if not active or active.closed then return end
  local name = active.name
  return {
    label = "end{" .. name .. "}",
    filterText = braces and name or ("end{" .. name .. "}"),
    kind = vim.lsp.protocol.CompletionItemKind.Text,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    score_offset = 1000,
    data = { latex_end_environment = name },
    source_id = "snippets",
    source_name = "Snippets",
    cursor_column = cursor[2],
    detail = "Close the nearest unmatched environment",
    textEdit = {
      newText = "\\end{" .. name .. "}",
      range = {
        start = { line = cursor[1] - 1, character = start - 1 },
        ["end"] = { line = cursor[1] - 1, character = finish },
      },
    },
  }
end

function M.items(ctx, items)
  items = vim.tbl_filter(function(item) return not (item.data and item.data.latex_end_environment) end, items)
  local item = M.item(ctx)
  if item then items[#items + 1] = item end
  return items
end

function M.execute(ctx, item, callback)
  if not (item.data and item.data.latex_end_environment) then return false end
  local closing = M.item(ctx, true)
  if closing and closing.data.latex_end_environment == item.data.latex_end_environment then
    local edit = closing.textEdit
    local first, last = edit.range.start, edit.range["end"]
    vim.api.nvim_buf_set_text(ctx.bufnr, first.line, first.character, last.line, last.character, { edit.newText })
    vim.api.nvim_win_set_cursor(0, { first.line + 1, first.character + #edit.newText })
  end
  if callback then callback() end
  return true
end

return M
