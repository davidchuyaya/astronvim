-- nvim --headless --noplugin -u NONE -l tests/latex-end-environment.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath "data" .. "/lazy/blink.cmp")
local ending = require "latex-end-environment"
vim.o.virtualedit = "onemore"
vim.bo.filetype = "tex"
local function context(lines)
  local cursor
  lines = vim.deepcopy(lines)
  for row, line in ipairs(lines) do
    local col = line:find("|", 1, true)
    if col then
      cursor = { row, col - 1 }
      lines[row] = line:sub(1, col - 1) .. line:sub(col + 1)
      break
    end
  end
  assert(cursor)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, cursor)
  return {
    bufnr = vim.api.nvim_get_current_buf(),
    line = lines[cursor[1]],
    cursor = cursor,
    mode = "default",
    get_line = function() return vim.api.nvim_get_current_line() end,
    get_cursor = function() return vim.api.nvim_win_get_cursor(0) end,
  }
end

for _, fixture in ipairs {
  { { "\\begin{enumerate}", "\\en|" }, "enumerate" },
  { { "\\begin{enumerate}", "\\end|" }, "enumerate" },
  { { "\\begin{enumerate}", "\\end{en|}" }, "enumerate" },
  { { "\\begin{align*}", "\\end|" }, "align*" },
  { { "\\begin{custom-env}", "α \\en| trailing" }, "custom-env" },
  { { "\\begin{enumerate}", "\\begin{itemize}", "\\en|" }, "itemize" },
  { { "\\begin{enumerate}", "\\begin{itemize}", "\\end{itemize}", "\\en|" }, "enumerate" },
  { { "\\begin{enumerate}", "\\en|", "% \\end{enumerate}" }, "enumerate" },
  { { "\\begin{enumerate}", "\\en|", "\\begin{enumerate}", "\\end{enumerate}" }, "enumerate" },
  { { "\\begin", "{enumerate}", "\\en|" }, "enumerate" },
} do
  local ctx = context(fixture[1])
  local item = assert(ending.item(ctx), vim.inspect(fixture))
  assert(item.data.latex_end_environment == fixture[2], vim.inspect(item))
  assert(item.source_id == "snippets" and item.cursor_column == ctx.cursor[2])
  assert(#ending.items(ctx, { item }) == 1, "Repeated transformation duplicated the end item")
  local called = 0
  assert(ending.execute(ctx, item, function() called = called + 1 end))
  assert(called == 1)
  local actual = vim.api.nvim_get_current_line()
  local expected = fixture[1][ctx.cursor[1]]
    :gsub("\\end{en|}", "\\end{" .. fixture[2] .. "}")
    :gsub("\\en[d]?|", "\\end{" .. fixture[2] .. "}")
  assert(actual == expected, vim.inspect { actual, expected })
end

for _, lines in ipairs {
  { "\\en|" },
  { "\\en|", "\\begin{enumerate}" },
  { "\\begin{enumerate}", "\\en|", "\\end{enumerate}" },
  { "\\begin{enumerate}", "\\end{enumerate}", "\\en|" },
  { "\\begin{enumerate}", "\\begin{itemize}", "\\en|", "\\end{itemize}" },
  { "% \\begin{enumerate}", "\\en|" },
  { "\\\\begin{enumerate}", "\\en|" },
  { "\\begin{enumerate}", "% \\en|" },
  { "\\begin{enumerate}", "\\\\en|" },
  { "\\verb+\\begin{enumerate}+", "\\en|" },
  { "\\verb*+\\begin{enumerate}+", "\\en|" },
  { "\\begin{verbatim}", "\\begin{enumerate}", "\\en|" },
  { "\\begin{lstlisting}", "\\begin{enumerate}", "\\end{lstlisting}", "\\en|" },
  { "\\begin{enumerate}", "\\emph|" },
} do
  local ctx = context(lines)
  assert(not ending.item(ctx), "Unexpected closer: " .. vim.inspect(lines))
end

-- A stale suggestion must not insert a duplicate after a collaborator adds an end.
local ctx = context { "\\begin{enumerate}", "\\en|" }
local item = assert(ending.item(ctx))
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "\\end{enumerate}" })
assert(ending.execute(ctx, item))
assert(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "\\en")

local spec = require("plugins.latex-snippets")[1]
local opts = {}
spec.opts(nil, opts)
local resolved
opts.sources.providers.snippets.override.resolve({}, item, function(value) resolved = value end)
assert(resolved == item, "End completion tried to resolve a nonexistent LuaSnip ID")

-- Use Blink's actual fuzzy matcher: the matching closer wins over plain end.
ctx = context { "\\begin{enumerate}", "\\en|" }
local config = require "blink.cmp.config"
config.fuzzy.frecency.enabled = false
local fuzzy = require "blink.cmp.fuzzy"
fuzzy.set_implementation "rust"
local ranked = fuzzy.fuzzy(ctx.line, ctx.cursor[2], {
  snippets = ending.items(ctx, {}),
  lsp = { { label = "end", kind = 3 } },
}, "prefix")
assert(ranked[1].data and ranked[1].data.latex_end_environment == "enumerate", "Closer was not first")
vim.bo.filetype = "lua"
assert(not ending.item(ctx), "Changed another language")
print "PASS: matching ends, nesting, later closers, comments/verbatim, acceptance, stale items and top ranking"
