local M = {}
local ns = vim.api.nvim_create_namespace("amazonq_ghost")
local timer = vim.uv.new_timer()
local current_text = nil -- stored insertion text
local current_bufnr = nil
local current_row = nil
local current_col = nil
local debounce_ms = 500

local function get_client()
  local clients = vim.lsp.get_clients({ bufnr = 0, name = "amazonq" })
  return clients[1]
end

local function clear()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
  current_text = nil
end

local function render(text, bufnr, row, col)
  clear()
  local lines = vim.split(text, "\n", { plain = true })
  if #lines == 0 then return end

  -- Text after cursor on the current line
  local cur_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local after_cursor = cur_line:sub(col + 1)

  local opts = {
    virt_text = { { lines[1], "Comment" } },
    virt_text_pos = "inline",
  }

  -- Multi-line: remaining lines as virt_lines
  if #lines > 1 then
    local virt_lines = {}
    for i = 2, #lines do
      table.insert(virt_lines, { { lines[i], "Comment" } })
    end
    -- Append whatever was after the cursor to the last virtual line
    if after_cursor ~= "" then
      local last = virt_lines[#virt_lines]
      table.insert(last, { after_cursor, "Normal" })
    end
    opts.virt_lines = virt_lines
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
  current_text = text
  current_bufnr = bufnr
  current_row = row
  current_col = col
end

local function request_completion()
  local client = get_client()
  if not client then return end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }

  client:request("aws/textDocument/inlineCompletionWithReferences", params, function(err, result)
    if err or not result or not result.items or #result.items == 0 then return end
    -- Only render if cursor hasn't moved
    vim.schedule(function()
      local cur = vim.api.nvim_win_get_cursor(0)
      if cur[1] - 1 == row and cur[2] == col and vim.api.nvim_get_current_buf() == bufnr then
        render(result.items[1].insertText, bufnr, row, col)
      end
    end)
  end, bufnr)
end

function M.is_visible()
  return current_text ~= nil
end

function M.accept()
  if not current_text then return end
  local text = current_text
  local bufnr = current_bufnr
  local row = current_row
  local col = current_col
  clear()
  -- Insert the text at the stored position
  local lines = vim.split(text, "\n", { plain = true })
  local cur_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local before = cur_line:sub(1, col)
  local after = cur_line:sub(col + 1)
  lines[1] = before .. lines[1]
  lines[#lines] = lines[#lines] .. after
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, lines)
  -- Place cursor at end of inserted text
  local end_row = row + #lines - 1
  local end_col = #lines[#lines] - #after
  vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
end

function M.dismiss()
  clear()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("amazonq_ghost", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI" }, {
    group = group,
    callback = function()
      clear()
      timer:stop()
      timer:start(debounce_ms, 0, vim.schedule_wrap(function()
        if vim.fn.mode() == "i" then request_completion() end
      end))
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    group = group,
    callback = function()
      timer:stop()
      clear()
    end,
  })
end

return M
