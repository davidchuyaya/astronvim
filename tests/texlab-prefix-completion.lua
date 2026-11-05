-- nvim --headless --noplugin -u NONE -l tests/texlab-prefix-completion.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local prefix = require "texlab-prefix-completion"
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".tex")
vim.api.nvim_set_current_buf(buf)
vim.bo.filetype = "tex"
local uri = vim.uri_from_bufnr(buf)
local client = { name = "texlab", offset_encoding = "utf-16", rpc = {}, handlers = {} }
local notices, calls, pending = {}, {}, {}
client.rpc.notify = function(method, params)
  notices[#notices + 1] = { method = method, params = params }
  return true
end
client.rpc.request = function(method, params, callback, notify)
  calls[#calls + 1] = { method = method, params = params, notify = notify }
  pending[#pending + 1] = callback
  return true, #calls
end
local saved_request = client.rpc.request
prefix.attach(client)
local wrapped = client.rpc.request
prefix.attach(client)
assert(wrapped == client.rpc.request, "Installed twice")
local function setup(line, before)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "\\documentclass{article}", line, "\\end{document}" })
  local _, utf16 = vim.str_utfindex(before)
  return { textDocument = { uri = uri }, position = { line = 1, character = utf16 } }
end
local function candidate(name, row, first, last)
  return {
    label = name,
    kind = 3,
    textEdit = {
      newText = name,
      range = {
        start = { line = row, character = first },
        ["end"] = { line = row, character = last },
      },
    },
  }
end

-- The actual buffer and original request stay intact. Only the virtual copy is truncated.
local params = setup("$\\Ghello$", "$\\G")
local original = vim.deepcopy(params)
local tick = vim.api.nvim_buf_get_changedtick(buf)
local result
local notify = function() end
local ok, id = client.rpc.request("textDocument/completion", params, function(_, value) result = value end, notify)
assert(ok and id == 1 and calls[1].notify == notify, "RPC IDs/cancellation hook changed")
assert(vim.deep_equal(original, params), "Original request mutated")
assert(vim.api.nvim_buf_get_changedtick(buf) == tick, "Actual buffer was edited")
assert(calls[1].params.textDocument.uri ~= uri and calls[1].params.position.line == 2)
assert(notices[1].method == "textDocument/didOpen")
assert(notices[1].params.textDocument.text:find("\n$\\G\n", 1, true))
assert(not notices[1].params.textDocument.text:find("hello", 1, true))
pending[1](nil, { items = { candidate("Gamma", 2, 2, 3) }, isIncomplete = false })
assert(notices[2].method == "textDocument/didClose")
assert(notices[2].params.textDocument.uri == notices[1].params.textDocument.uri)
assert(result.isIncomplete and result.items[1].textEdit.range.start.line == 1)
assert(result.items[1].textEdit.newText == "Gamma{}")
vim.lsp.util.apply_text_edits({ result.items[1].textEdit }, buf, "utf-16")
assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "$\\Gamma{}hello$", "Following text was lost")

-- Different completion categories do not need a table of special-cased commands.
for _, fixture in ipairs {
  { "\\cite{sahello.", "\\cite{sa", "sample2024", "\\cite{sample2024}hello.", 6 },
  { "\\begin{enuhello}", "\\begin{enu", "enumerate", "\\begin{enumerate}hello}", 7 },
  { "\\Cref{sechello}", "\\Cref{sec", "sec:one", "\\Cref{sec:one}hello}", 6 },
  { "\\include{fileother}", "\\include{file", "filename", "\\include{filename}other}", 9 },
} do
  params = setup(fixture[1], fixture[2])
  local n = #calls + 1
  client.rpc.request("textDocument/completion", params, function(_, value) result = value end)
  pending[n](nil, { candidate(fixture[3], 2, fixture[5], #fixture[2]) })
  vim.lsp.util.apply_text_edits({ result.items[1].textEdit }, buf, "utf-16")
  assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == fixture[4], fixture[1])
end

-- Keep existing closing braces and punctuation, and don't add groups before '$'.
for _, fixture in ipairs {
  { "$\\G$", "$\\G", "Gamma", "$\\Gamma$", 2 },
} do
  params = setup(fixture[1], fixture[2])
  local shadow = assert(prefix.snapshot(client, params, buf))
  result = prefix.result({ candidate(fixture[3], 2, fixture[5], #fixture[2]) }, shadow)
  vim.lsp.util.apply_text_edits({ result.items[1].textEdit }, buf, "utf-16")
  assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == fixture[4])
end

-- Before a closing argument brace the normal token is already prefix-only.
-- Keep the actual URI/project graph instead of querying an orphan subfile.
for _, fixture in ipairs {
  { "\\cite{sa}.", "\\cite{sa", 6, "\\cite{sample2024}." },
  { "\\cite{paxos,}", "\\cite{paxos,", 12, "\\cite{paxos,sample2024}" },
  { "\\cite{paxos,sa}", "\\cite{paxos,sa", 12, "\\cite{paxos,sample2024}" },
  { "\\cite{paxos, }", "\\cite{paxos, ", 13, "\\cite{paxos, sample2024}" },
} do
  params = setup(fixture[1], fixture[2])
  assert(not prefix.snapshot(client, params, buf), fixture[1])
  local n, count = #calls + 1, #notices
  client.rpc.request("textDocument/completion", params, function(_, value) result = value end)
  assert(#notices == count and calls[n].params == params, "Created an unnecessary shadow")
  pending[n](nil, { candidate("sample2024", 1, fixture[3], #fixture[2]) })
  vim.lsp.util.apply_text_edits({ result.items[1].textEdit }, buf, "utf-16")
  assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == fixture[4])
end
params = setup("\\text{\\G}", "\\text{\\G")
assert(prefix.snapshot(client, params, buf), "Disabled command-prefix queries inside braces")

-- Unicode offsets, end-of-line responses and unrelated methods/languages.
params = setup("α😀 $\\Ghello$", "α😀 $\\G")
local shadow = assert(prefix.snapshot(client, params, buf))
assert(shadow.params.position.character == params.position.character)
assert(shadow.text:find("α😀 $\\G\n", 1, true))
params = setup("\\Gamma", "\\Gamma")
assert(not prefix.snapshot(client, params, buf))
assert(prefix.result({ items = {} }, nil).isIncomplete)
local count = #notices
client.rpc.request("textDocument/hover", params, function() end)
assert(#notices == count and calls[#calls].params == params)
client.rpc.request("shutdown", vim.NIL, function() end)
assert(#notices == count, "Shutdown was intercepted")
vim.bo.filetype = "lua"
client.rpc.request("textDocument/completion", params, function() end)
assert(#notices == count)
vim.bo.filetype = "tex"

-- Concurrent requests get distinct documents and close only their own snapshot.
params = setup("$\\Ghello$", "$\\G")
local first, second = #calls + 1, #calls + 2
client.rpc.request("textDocument/completion", params, function() end)
client.rpc.request("textDocument/completion", params, function() end)
local first_uri, second_uri = calls[first].params.textDocument.uri, calls[second].params.textDocument.uri
assert(first_uri ~= second_uri)
pending[second]({ code = -32800, message = "Cancelled" }, nil)
assert(notices[#notices].params.textDocument.uri == second_uri)
pending[first](nil, { items = {} })
assert(notices[#notices].params.textDocument.uri == first_uri)

-- Failed requests still close their snapshots; ghost diagnostics cannot create buffers.
client.rpc.request = saved_request
client._prefix_completion = nil
client.rpc.request = function() return false end
prefix.attach(client)
client.rpc.request("textDocument/completion", params, function() error "Unexpected callback" end)
assert(notices[#notices].method == "textDocument/didClose")
local before = #vim.api.nvim_list_bufs()
client.handlers["textDocument/publishDiagnostics"](nil, { uri = second_uri, diagnostics = {} })
assert(#vim.api.nvim_list_bufs() == before, "Ghost diagnostic created a buffer")

print "PASS: prefix snapshots, suffix preservation, Unicode, mapping, cleanup, concurrent requests and error paths"
