-- Query prefix-only completions without editing the real buffer or LSP document.
local M = {}
local sequence = 0

local function is_tex(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  return vim.bo[buf].filetype == "tex" or vim.bo[buf].filetype == "plaintex"
end

function M.snapshot(client, params, buf)
  if not is_tex(buf) or not params or not params.position or not params.textDocument then return end
  local uri = params.textDocument.uri
  if not uri or not uri:match "^file:" or uri ~= vim.uri_from_bufnr(buf) then return end
  local row, character = params.position.line, params.position.character
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line then return end
  local encoding = client.offset_encoding or "utf-16"
  local ok, byte
  if encoding == "utf-8" then
    ok, byte = true, character
  elseif vim.fn.has "nvim-0.11" == 1 then
    ok, byte = pcall(vim.str_byteindex, line, encoding, character, false)
  else
    ok, byte = pcall(vim.str_byteindex, line, character, encoding == "utf-16")
  end
  if not ok or byte < 0 or byte >= #line then return end
  local filename = vim.uri_to_fname(uri)
  if filename:find "[\r\n]" then return end
  local prefix, suffix = line:sub(1, byte), line:sub(byte + 1)
  if suffix:match "^%s" then return end
  -- At an argument's closing brace there is no token suffix to remove.
  -- Query the real document: a standalone shadow of an included chapter is
  -- not part of TexLab's parent/input graph and can lose its bibliography.
  -- Keep shadows for actual suffix text and commands nested in arguments.
  if suffix:sub(1, 1) == "}" and prefix:match "[{,][^{}\\]*$" then return end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  lines[row + 1] = prefix
  -- Give the copy the original file's root hint. This does not itself make
  -- the copy an input child of that file's parent/main document.
  table.insert(lines, 1, "% !TeX root = " .. filename)
  sequence = sequence + 1
  local shadow_uri = vim.uri_from_fname(
    vim.fn.fnamemodify(filename, ":h") .. "/.__nvim_prefix_" .. vim.fn.getpid() .. "_" .. sequence .. ".tex"
  )
  local copy = vim.deepcopy(params)
  copy.textDocument.uri = shadow_uri
  copy.position.line = row + 1
  local command_start = prefix:find "\\%a*$"
  local escapes = command_start and prefix:sub(1, command_start - 1):match "(\\*)$"
  return {
    uri = shadow_uri,
    original_uri = uri,
    params = copy,
    text = table.concat(lines, "\n") .. (vim.bo[buf].eol and "\n" or ""),
    separate_command = command_start and #escapes % 2 == 0 and suffix:match "^%a" ~= nil,
    close_argument = prefix:match "\\%a+%*?%s*{[^{}]*$" ~= nil and not suffix:match "^[},]",
  }
end

local function map_position(position)
  if not position or position.line < 1 then return end
  position.line = position.line - 1
  return position
end

local function map_range(range)
  return range and map_position(range.start) and map_position(range["end"]) and range or nil
end

local function map_edit(edit)
  if edit.range then
    edit.range = map_range(edit.range)
  else
    edit.insert, edit.replace = map_range(edit.insert), map_range(edit.replace)
  end
end

local function map_uris(value, shadow)
  for key, entry in pairs(value) do
    if type(entry) == "table" then
      map_uris(entry, shadow)
    elseif entry == shadow.uri then
      value[key] = shadow.original_uri
    end
  end
end

function M.result(result, shadow)
  if type(result) ~= "table" then return result end
  result = vim.deepcopy(result)
  if not result.items then result = { items = result } end
  -- Prefix-filtered subsets cannot safely be cached while the user types.
  result.isIncomplete = true
  if not shadow then return result end
  local defaults = result.itemDefaults
  if defaults and defaults.editRange then
    if defaults.editRange.start then
      defaults.editRange = map_range(defaults.editRange)
    else
      defaults.editRange.insert = map_range(defaults.editRange.insert)
      defaults.editRange.replace = map_range(defaults.editRange.replace)
    end
  end
  for _, item in ipairs(result.items) do
    if item.textEdit then map_edit(item.textEdit) end
    for _, edit in ipairs(item.additionalTextEdits or {}) do
      map_edit(edit)
    end
    if shadow.separate_command then
      local text = item.textEdit and item.textEdit.newText or item.textEditText or item.insertText
      if text and text:match "^\\?%a+$" then
        -- Preserve suffix letters without turning \Gamma + hello into the
        -- unrelated command \Gammahello. This group is a TeX delimiter.
        text = text .. "{}"
        if item.textEdit then item.textEdit.newText = text end
        if item.textEditText then item.textEditText = text end
        if item.insertText then item.insertText = text end
        item.kind = vim.lsp.protocol.CompletionItemKind.Constant
      end
    elseif shadow.close_argument then
      local text = item.textEdit and item.textEdit.newText or item.textEditText or item.insertText
      if text and not text:find "[{}\n$]" then
        text = text .. "}"
        if item.textEdit then item.textEdit.newText = text end
        if item.textEditText then item.textEditText = text end
        if item.insertText then item.insertText = text end
      end
    end
  end
  map_uris(result, shadow)
  return result
end

function M.attach(client)
  if not client or client.name ~= "texlab" or not client.rpc or client._prefix_completion then return end
  client._prefix_completion = true
  local original = client.rpc.request
  -- At the transport boundary, other completion wrappers continue to see the
  -- real document URI, request position and buffer coordinates.
  client.handlers = client.handlers or {}
  local diagnostics = client.handlers["textDocument/publishDiagnostics"]
  local marker = "/.__nvim_prefix_" .. vim.fn.getpid() .. "_"
  client.handlers["textDocument/publishDiagnostics"] = function(err, params, ...)
    if params and params.uri and params.uri:find(marker, 1, true) then return end
    local handler = diagnostics or vim.lsp.handlers["textDocument/publishDiagnostics"]
    if handler then return handler(err, params, ...) end
  end
  client.rpc.request = function(method, params, callback, notify_reply)
    local uri = type(params) == "table" and params.textDocument and params.textDocument.uri
    local buf = uri and uri:match "^file:" and vim.fn.bufnr(vim.uri_to_fname(uri)) or -1
    if method ~= "textDocument/completion" or type(callback) ~= "function" or not is_tex(buf) then
      return original(method, params, callback, notify_reply)
    end
    local shadow = M.snapshot(client, params, buf)
    local closed = false
    local function close()
      if shadow and not closed then
        closed = true
        pcall(client.rpc.notify, "textDocument/didClose", { textDocument = { uri = shadow.uri } })
      end
    end
    if shadow then
      local opened = client.rpc.notify("textDocument/didOpen", {
        textDocument = { uri = shadow.uri, languageId = "latex", version = 1, text = shadow.text },
      })
      if not opened then shadow = nil end
    end
    local ok, success, id = pcall(original, method, shadow and shadow.params or params, function(err, result)
      close()
      if not err then result = M.result(result, shadow) end
      callback(err, result)
    end, notify_reply)
    if not ok or not success then close() end
    if not ok then error(success) end
    return success, id
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("TexLabPrefixCompletion", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event) M.attach(vim.lsp.get_client_by_id(event.data.client_id)) end,
  })
  for _, client in ipairs(vim.lsp.get_clients { name = "texlab" }) do
    M.attach(client)
  end
end

return M
