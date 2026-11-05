-- nvim --headless --noplugin -u NONE -l tests/texlab-subfile-completion.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local root = vim.fn.getcwd() .. "/tests/fixtures/texlab-subfile"
vim.cmd.edit(root .. "/chapter.tex")
local buf = vim.api.nvim_get_current_buf()
vim.bo.filetype = "tex"
local id = vim.lsp.start {
  name = "texlab",
  cmd = { vim.fn.stdpath "data" .. "/mason/bin/texlab" },
  root_dir = root,
}
local client = assert(vim.lsp.get_client_by_id(id))
assert(vim.wait(5000, function() return client.initialized end, 10), "TexLab did not initialize")
assert(
  vim.wait(3000, function()
    local reply = client:request_sync("workspace/symbol", { query = "paxos" }, 1000, buf)
    return reply and reply.result and #reply.result > 0
  end, 20),
  "TexLab did not index the bibliography"
)
require("texlab-prefix-completion").attach(client)
for _, text in ipairs { "\\cite{paxos,}", "\\cite{paxos,sa}", "\\cite{sa}" } do
  local line = "Subfile citation: " .. text
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  local character = #line - 1
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local reply = assert(client:request_sync("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = 0, character = character },
  }, 3000, buf))
  assert(not reply.err, vim.inspect(reply.err))
  assert(vim.api.nvim_buf_get_changedtick(buf) == tick, "Completion edited the real document")
  local sample
  for _, item in ipairs(reply.result.items or reply.result) do
    if item.label == "sample2024" then sample = item end
  end
  assert(sample, "Missing bibliography keys in subfile: " .. text)
  vim.lsp.util.apply_text_edits({ sample.textEdit }, buf, client.offset_encoding)
  local expected = text:find("paxos,", 1, true) and "\\cite{paxos,sample2024}" or "\\cite{sample2024}"
  assert(vim.api.nvim_get_current_line() == "Subfile citation: " .. expected, "Wrong citation replacement")
end
client:stop(true)
vim.bo.modified = false
print "PASS: real TexLab subfile citations retain the parent bibliography, existing keys and closing braces"
vim.cmd "qa!"
