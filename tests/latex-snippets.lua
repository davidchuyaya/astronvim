-- Run from the config directory: nvim --headless --noplugin -u NONE -l tests/latex-snippets.lua
local root = vim.fn.getcwd()
local lazy = vim.fn.stdpath "data" .. "/lazy/"
vim.opt.runtimepath:prepend(root)
for _, plugin in ipairs { "LuaSnip", "blink.cmp", "friendly-snippets" } do
  vim.opt.runtimepath:append(lazy .. plugin)
end

local luasnip = require "luasnip"
luasnip.config.setup {}
vim.bo.filetype = "tex"
require("luasnip.loaders.from_vscode").load {
  paths = { lazy .. "friendly-snippets" },
  include = { "tex", "plaintex" },
}

local source = require("blink.cmp.sources.snippets.luasnip").new {}
local ctx = { bufnr = vim.api.nvim_get_current_buf(), line = "\\emph", cursor = { 1, 6 } }
local function get_items()
  local items
  source:get_completions(ctx, function(result) items = result.items end)
  assert(items, "LuaSnip did not return completion items")
  return items
end

local calls = 0
local opts = {
  keymap = { ["<CR>"] = { "select_and_accept", "fallback" } },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
    providers = {
      snippets = {
        transform_items = function(_, items)
          calls = calls + 1
          return items
        end,
      },
    },
  },
}
local defaults, keymap = opts.sources.default, opts.keymap
require("plugins.latex-snippets")[1].opts(nil, opts)
assert(opts.sources.default == defaults and opts.keymap == keymap, "Existing completion settings changed")
local filter = opts.sources.providers.snippets.transform_items
local function labels(items)
  local result = {}
  for _, item in ipairs(items) do
    result[item.label] = item
  end
  return result
end

local before = get_items()
local all = labels(before)
assert(all.template and all["\\template"], "Fixture must include both whole-document templates")
local started = vim.uv.hrtime()
local filtered = labels(filter(ctx, before))
local first_ms = (vim.uv.hrtime() - started) / 1e6
assert(calls == 1, "Existing source transform was not called")
assert(not filtered.template and not filtered["\\template"], "Document templates remain in completion")
for _, name in ipairs { "FEM", "BEN", "enumerate", "table", "algo", "plotenvironment2d", "plotenvironment3d" } do
  assert(all[name] and filtered[name], "Useful snippet was removed: " .. name)
end
local removed = {}
for name in pairs(all) do
  if not filtered[name] then table.insert(removed, name) end
end
table.sort(removed)
assert(#removed == 2, "Unexpected installed snippets removed: " .. table.concat(removed, ", "))

-- Exercise size boundaries and body-based matching with names unrelated to templates.
local function lines(n) return string.rep("x\n", n - 1) .. "x" end
local bodies = {
  keep25 = lines(25),
  hide26 = lines(26),
  keep1500 = string.rep("x", 1500),
  hide1501 = string.rep("x", 1501),
  tinyScaffold = "\\documentclass{article}\n\\begin{document}\n${0}\n\\end{document}",
  documentclassOnly = "\\documentclass{${1:article}}",
}
local custom = {}
for name, body in pairs(bodies) do
  table.insert(custom, luasnip.parser.parse_snippet(name, body))
end
luasnip.add_snippets("tex", custom)
local updated = labels(filter(ctx, get_items()))
for _, name in ipairs { "keep25", "keep1500", "documentclassOnly" } do
  assert(updated[name], name)
end
for _, name in ipairs { "hide26", "hide1501", "tinyScaffold" } do
  assert(not updated[name], name)
end

-- Decisions are cached by snippet object, not completion label or numeric ID.
local cached = luasnip.parser.parse_snippet("cached", "hello")
local count = 0
local docstring = cached.get_docstring
cached.get_docstring = function(self)
  count = count + 1
  return docstring(self)
end
luasnip.add_snippets("tex", { cached }, { key = "cache-test" })
filter(ctx, get_items())
filter(ctx, get_items())
assert(count == 1, "Snippet bodies should only be inspected once")
luasnip.add_snippets("tex", { luasnip.parser.parse_snippet("cached", lines(26)) }, { key = "cache-test" })
assert(not labels(filter(ctx, get_items())).cached, "Reloaded snippet kept a stale decision")

-- Unknown items/docstring failures stay available. Other languages are unchanged.
local unknown = { { label = "custom" }, { label = "stale", data = { snip_id = -1 } } }
assert(#filter(ctx, unknown) == #unknown)
local broken = luasnip.parser.parse_snippet("broken", "hello")
broken.get_docstring = function() error "unavailable preview" end
luasnip.add_snippets("tex", { broken })
assert(labels(filter(ctx, get_items())).broken, "Docstring errors should not break completion")
vim.bo.filetype = "lua"
assert(filter(ctx, before) == before, "Non-TeX completion changed")
vim.bo.filetype = "plaintex"
assert(not labels(filter(ctx, before)).template, "plaintex is not filtered")
vim.bo.filetype = "tex"

-- The retained environment still expands normally.
luasnip.snip_expand(luasnip.get_id_snippet(filtered.enumerate.data.snip_id):copy())
local expanded = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(expanded:find("\\begin{enumerate}", 1, true) and expanded:find("\\end{enumerate}", 1, true))
assert(luasnip.session.current_nodes[ctx.bufnr], "Environment did not create a snippet session")
vim.api.nvim_feedkeys("", "x", true) -- finish LuaSnip's queued normal-to-insert jump

-- Reuse the installed environment snippets inside a partially typed \begin.
local environments = require "latex-environments"
local execute = opts.sources.providers.snippets.override.execute
local function completion_context(line, col)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "tex"
  vim.bo.expandtab = true
  vim.bo.shiftwidth = 2
  vim.bo.tabstop = 2
  vim.bo.softtabstop = 2
  vim.o.virtualedit = "onemore"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, col or #line })
  ctx = {
    bufnr = buf,
    mode = "default",
    line = line,
    cursor = vim.api.nvim_win_get_cursor(0),
    get_line = function() return vim.api.nvim_get_current_line() end,
    get_cursor = function() return vim.api.nvim_win_get_cursor(0) end,
  }
  return labels(filter(ctx, get_items()))
end

for _, fixture in ipairs {
  { "beginenu", "", "enumerate" },
  { "\\beginenu", "", "enumerate" },
  { "beginenumerate", "", "enumerate" },
  { "beginenumerate", "", "enumerate", #"beginenu" },
  { "  beginenu", "  ", "enumerate" },
  { "é beginenu", "é ", "enumerate" },
  { "beginite", "", "itemize" },
  { "\\beginite", "", "itemize" },
  { "begin{enu}", "", "enumerate", #"begin{enu" },
  { "\\begin{enu", "", "enumerate" },
  { "\\begin{enumerate", "", "enumerate" },
  { "\\begin{enu}", "", "enumerate", #"\\begin{enu" },
  { "\\begin{enumerate}", "", "enumerate", #"\\begin{enu" },
  { "  \\begin{enu}", "  ", "enumerate", #"  \\begin{enu" },
  { "é \\begin{enu}", "é ", "enumerate", #"é \\begin{enu" },
  { "\\begin{ite", "", "itemize" },
} do
  local candidates = completion_context(fixture[1], fixture[4])
  assert(candidates[fixture[3]], "Missing environment snippet: " .. fixture[1])
  assert(candidates[fixture[3]].score_offset == 1000, "Environment snippet was not prioritized")
  assert(not candidates.emph and not candidates.template, "Non-environments offered inside \\begin")
  local calls = 0
  execute(
    { execute = function() error "Unexpected fallback" end },
    ctx,
    candidates[fixture[3]],
    function() calls = calls + 1 end
  )
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(#lines == 3, "Unexpected expansion: " .. vim.inspect(lines))
  assert(lines[1] == fixture[2] .. "\\begin{" .. fixture[3] .. "}", vim.inspect(lines))
  assert(lines[3] == (fixture[2]:match "^%s*" or "") .. "\\end{" .. fixture[3] .. "}", vim.inspect(lines))
  assert(lines[2]:match "\\item $", "Missing first item: " .. vim.inspect(lines))
  -- In headless normal mode LuaSnip queues its jump into insert mode. Type
  -- through that queue to prove the next keystrokes really go after \item.
  vim.api.nvim_feedkeys("CURSOR" .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  local typed = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(typed[2] == lines[2] .. "CURSOR", "Typing did not land after \\item: " .. vim.inspect(typed))
  assert(calls == 1, "Blink execution callback was not completed")
end

local candidates = completion_context "\\begin{equ"
execute({}, ctx, candidates.equation)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "\\begin{equation}" and lines[#lines] == "\\end{equation}", vim.inspect(lines))
vim.api.nvim_feedkeys("", "x", true)

-- Leave regular triggers, \end, comments and other languages alone.
for _, line in ipairs {
  "enumerate",
  "\\end{enu",
  "% \\begin{enu",
  "\\\\begin{enu",
  "\\\\beginenu",
  "foobeginenu",
  "_beginenu",
  "% beginenu",
} do
  completion_context(line)
  assert(not environments.region(ctx), "Incorrect environment context: " .. line)
end
completion_context "\\% \\begin{enu"
assert(environments.region(ctx), "Escaped percent was treated as a comment")
vim.bo.filetype = "lua"
assert(not environments.region(ctx), "Changed another language")
vim.bo.filetype = "plaintex"
assert(environments.region(ctx), "Missing plaintex support")
local delegated = 0
execute({ execute = function() delegated = delegated + 1 end }, ctx, { data = {} })
assert(delegated == 1, "Ordinary snippet execution was not preserved")

-- Use Blink's real fuzzy matcher, rather than only checking score fields:
-- compact words must match, and the snippet must outrank an LSP/word match.
local config = require "blink.cmp.config"
config.fuzzy.frecency.enabled = false -- don't touch the user's completion database
local fuzzy = require "blink.cmp.fuzzy"
for _, implementation in ipairs { "lua", "rust" } do
  fuzzy.set_implementation(implementation)
  fuzzy.haystacks_by_provider_cache = {}
  for _, line in ipairs { "beginenu", "\\beginenu", "\\begin{enu", "\\begin{enumerate" } do
    completion_context(line)
    local snippets = filter(ctx, get_items())
    local normal = {
      { label = "enumerate", kind = vim.lsp.protocol.CompletionItemKind.Class },
      { label = "beginenu", kind = vim.lsp.protocol.CompletionItemKind.Text },
    }
    local ranked = fuzzy.fuzzy(line, #line, { snippets = snippets, lsp = normal }, "prefix")
    assert(ranked[1] and ranked[1].data and ranked[1].data.latex_environment, "Snippet was not top for " .. line)
    assert(ranked[1].label == "enumerate", "Wrong environment was ranked first: " .. ranked[1].label)
    -- A cached/re-resolved item must not accumulate priority bonuses.
    local again = filter(ctx, { ranked[1] })
    assert(again[1].score_offset == 1000, "Priority accumulated when re-transforming")
  end
end
completion_context "enumerate"
assert(not labels(filter(ctx, get_items())).enumerate.score_offset, "Normal snippet ranking changed")

-- Exercise Blink's provider cache across actual successive keystrokes. Asking
-- for completions only after the full word is typed misses this path.
config.snippets.preset = "luasnip"
local provider_config = vim.tbl_deep_extend("force", config.sources.providers.snippets, opts.sources.providers.snippets)
local provider = require("blink.cmp.sources.lib.provider").new("snippets", provider_config)
completion_context "b"
local function request_typed(line)
  vim.api.nvim_buf_set_lines(ctx.bufnr, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, #line })
  ctx.line, ctx.cursor = line, { 1, #line }
  ctx.id = 123
  ctx.bounds = { start_col = 1, length = #line }
  ctx.trigger = { kind = vim.lsp.protocol.CompletionTriggerKind.Invoked }
  local items, cached
  local requested_context = vim.tbl_extend("force", {}, ctx)
  provider:get_completions(requested_context, function(result, is_cached)
    items, cached = result, is_cached
  end)
  assert(items, "Provider did not return completions")
  return items, cached
end
for length = 1, #"beginenu" do
  local line = ("beginenu"):sub(1, length)
  local items, cached = request_typed(line)
  if length == #"beginenu" then
    local ranked = fuzzy.fuzzy(line, #line, { snippets = items }, "prefix")
    assert(
      ranked[1] and ranked[1].label == "enumerate" and ranked[1].data.latex_environment,
      "Typing beginenu did not produce its snippet (cached=" .. tostring(cached) .. ")"
    )
  end
end
local ordinary = labels(request_typed "begi")
assert(ordinary.enumerate and not ordinary.enumerate.data.latex_environment, "Backspacing kept contextual snippets")

for _, word in ipairs { "\\beginenu", "\\begin{enu", "beginite" } do
  provider.list:destroy()
  provider.list = nil
  for length = 1, #word do
    local line = word:sub(1, length)
    local items = request_typed(line)
    if length == #word then
      local ranked = fuzzy.fuzzy(line, #line, { snippets = items }, "prefix")
      local expected = word == "beginite" and "itemize" or "enumerate"
      assert(ranked[1] and ranked[1].label == expected and ranked[1].data.latex_environment, word)
    end
  end
end

-- Resolve and accept through the actual provider override, including Blink's
-- asynchronous resolve path, then type into the expanded snippet.
local final_items = request_typed "beginenu"
local chosen = fuzzy.fuzzy("beginenu", #"beginenu", { snippets = final_items }, "prefix")[1]
local accepted, failure = false, nil
provider
  :resolve(ctx, chosen)
  :map(function(item)
    return provider:execute(ctx, item, function() error "Unexpected default acceptance" end)
  end)
  :map(function() accepted = true end)
  :catch(function(err) failure = err end)
assert(vim.wait(1000, function() return accepted or failure ~= nil end, 10), "Snippet acceptance timed out")
assert(not failure, tostring(failure))
vim.api.nvim_feedkeys("PROVIDER" .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
local accepted_lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
assert(accepted_lines[1] == "\\begin{enumerate}", vim.inspect(accepted_lines))
assert(accepted_lines[2]:match "\\item PROVIDER$", vim.inspect(accepted_lines))
assert(accepted_lines[3] == "\\end{enumerate}", vim.inspect(accepted_lines))

-- Keep normal caching for other languages; this refresh is TeX-only.
vim.bo.filetype = "lua"
request_typed "b"
assert(not provider.list.is_incomplete_forward and not provider.list.is_incomplete_backward)
local _, cached = request_typed "be"
assert(cached, "Changed snippet caching outside TeX")

print(
  string.format(
    "PASS: filtering, incremental typing/provider cache, ranking, resolve/accept and cursor placement (first filter %.1f ms)",
    first_ms
  )
)
