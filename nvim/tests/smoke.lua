-- Usage: nvim --headless -u init.lua -l tests/smoke.lua
-- Pins today's behaviour as literals. Run after startup with the real config.
local failures = {}

local function check(name, cond)
  if not cond then
    table.insert(failures, name)
  end
end

local function eq(name, got, want)
  if not vim.deep_equal(got, want) then
    table.insert(failures, name .. "\n  got:  " .. vim.inspect(got) .. "\n  want: " .. vim.inspect(want))
  end
end

local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do
    s[v] = true
  end
  return s
end

local Config = require("lazy.core.config")
local Plugin = require("lazy.core.plugin")

local function merged_opts(name)
  return Plugin.values(Config.plugins[name], "opts", false)
end

-- lazy: no warnings or errors while building the spec
for _, n in ipairs(Config.spec.notifs) do
  check("lazy notif: " .. tostring(n[1]), n[2] < vim.log.levels.WARN)
end
check("vim.v.errmsg is empty: " .. vim.v.errmsg, vim.v.errmsg == "")

-- filetype detection
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local function write(rel, lines)
  local path = tmp .. "/" .. rel
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
  return path
end
check("main.tf -> terraform", vim.filetype.match({ filename = write("main.tf", {}) }) == "terraform")
check(
  "cloudformation yaml",
  vim.filetype.match({ filename = write("cf.yaml", { "AWSTemplateFormatVersion: '2010-09-09'" }) })
    == "yaml.cloudformation"
)
check("plain yaml", vim.filetype.match({ filename = write("plain.yaml", { "a: 1" }) }) == "yaml")
write("dbt/dbt_project.yml", { "name: x" })
check("dbt sql", vim.filetype.match({ filename = write("dbt/models/a.sql", { "select 1" }) }) == "sql.dbt")

-- treesitter language aliases
local get_lang = vim.treesitter.language.get_lang
check("sql.dbt -> sql", get_lang("sql.dbt") == "sql")
check("yaml.cloudformation -> yaml", get_lang("yaml.cloudformation") == "yaml")
check("terraform-vars -> terraform", get_lang("terraform-vars") == "terraform")
check("dbt does not map to sql", get_lang("dbt") ~= "sql")

-- diagnostics
local diag = vim.diagnostic.config()
check(
  "diagnostic virtual_text.current_line",
  type(diag.virtual_text) == "table" and diag.virtual_text.current_line == true
)
check("diagnostic severity_sort", diag.severity_sort == true)
check("diagnostic float.border", diag.float and diag.float.border == "rounded")
check("diagnostic float.source", diag.float and diag.float.source == true)
check("diagnostic jump.on_jump", diag.jump and type(diag.jump.on_jump) == "function")

-- conform
local conform = merged_opts("conform.nvim")
eq("conform formatters_by_ft", conform.formatters_by_ft, {
  lua = { "stylua" },
  python = { "ruff_organize_imports", "ruff_format" },
  javascript = { "prettier" },
  javascriptreact = { "prettier" },
  typescript = { "prettier" },
  typescriptreact = { "prettier" },
  html = { "prettier" },
  css = { "prettier" },
  json = { "prettier" },
  jsonc = { "prettier" },
  yaml = { "prettier" },
  ["yaml.cloudformation"] = { "prettier" },
  markdown = { "prettier" },
  sh = { "shfmt" },
  bash = { "shfmt" },
  sql = { "sqlfluff" },
  ["sql.dbt"] = { "sqlfluff" },
  dbt = { "sqlfluff" },
  terraform = { "terraform_fmt" },
  ["terraform-vars"] = { "terraform_fmt" },
  hcl = { "terraform_fmt" },
})
eq("conform format_on_save", conform.format_on_save, { timeout_ms = 1500, lsp_format = "fallback" })

-- nvim-lint
require("lazy").load({ plugins = { "nvim-lint" } })
eq("nvim-lint linters_by_ft", require("lint").linters_by_ft, {
  javascript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },
  sh = { "shellcheck" },
  bash = { "shellcheck" },
  dockerfile = { "hadolint" },
  sql = { "sqlfluff" },
  ["sql.dbt"] = { "sqlfluff" },
  dbt = { "sqlfluff" },
  terraform = { "tflint" },
  ["terraform-vars"] = { "tflint" },
  hcl = { "tflint" },
  markdown = { "markdownlint-cli2" },
  yaml = { "yamllint" },
  ["yaml.cloudformation"] = { "cfn_lint" },
})

-- mason tools (sqlfluff depends on the host python, so it is excluded)
local tools = merged_opts("mason-tool-installer.nvim")
local got_tools = set_of(tools.ensure_installed)
got_tools.sqlfluff = nil
eq(
  "mason tools",
  got_tools,
  set_of({
    "stylua",
    "prettier",
    "shfmt",
    "shellcheck",
    "eslint_d",
    "hadolint",
    "tflint",
    "cfn-lint",
    "ruff",
    "debugpy",
    "java-debug-adapter",
    "java-test",
    "terraform",
    "markdownlint-cli2",
    "yamllint",
    "actionlint",
  })
)
check("mason tools run_on_start", tools.run_on_start == true)

-- LSP (mason-lspconfig is stubbed: its setup refreshes the registry over the network)
local captured
package.loaded["mason-lspconfig"] = {
  setup = function(o)
    captured = o
  end,
}
require("lazy").load({ plugins = { "nvim-lspconfig" } })
check("mason-lspconfig.setup was called", captured ~= nil)
captured = captured or {}
eq("lsp ensure_installed", captured.ensure_installed, {
  "lua_ls",
  "basedpyright",
  "ruff",
  "vtsls",
  "html",
  "cssls",
  "tailwindcss",
  "emmet_ls",
  "jsonls",
  "yamlls",
  "taplo",
  "marksman",
  "bashls",
  "dockerls",
  "terraformls",
  "jdtls",
})
eq("lsp automatic_enable.exclude", captured.automatic_enable and captured.automatic_enable.exclude, { "jdtls" })
check("lsp * capabilities.textDocument.completion", vim.lsp.config["*"].capabilities.textDocument.completion ~= nil)

local lua_ls = vim.lsp.config.lua_ls.settings.Lua
check("lua_ls LuaJIT", lua_ls.runtime.version == "LuaJIT")
check("lua_ls library[1] is VIMRUNTIME", lua_ls.workspace.library[1] == vim.env.VIMRUNTIME)
check("lua_ls telemetry off", lua_ls.telemetry.enable == false)
local pyright = vim.lsp.config.basedpyright.settings.basedpyright
check("basedpyright disableOrganizeImports", pyright.disableOrganizeImports == true)
check("basedpyright standard", pyright.analysis.typeCheckingMode == "standard")
eq("emmet_ls filetypes", vim.lsp.config.emmet_ls.filetypes, { "html", "css", "javascriptreact", "typescriptreact" })
eq("terraformls filetypes", vim.lsp.config.terraformls.filetypes, { "terraform", "terraform-vars", "hcl" })
local json = vim.lsp.config.jsonls.settings.json
check("jsonls validate.enable", json.validate.enable == true)
check("jsonls schemas is a table", type(json.schemas) == "table")
local yamlls = vim.lsp.config.yamlls
eq(
  "yamlls filetypes",
  yamlls.filetypes,
  { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values", "yaml.cloudformation" }
)
eq("yamlls customTags", yamlls.settings.yaml.customTags, {
  "!And sequence",
  "!If sequence",
  "!Not sequence",
  "!Equals sequence",
  "!Or sequence",
  "!FindInMap sequence",
  "!Base64 scalar",
  "!Cidr sequence",
  "!Ref scalar",
  "!Sub scalar",
  "!Sub sequence",
  "!GetAtt scalar",
  "!GetAtt sequence",
  "!GetAZs scalar",
  "!ImportValue scalar",
  "!ImportValue sequence",
  "!Select sequence",
  "!Split sequence",
  "!Join sequence",
})
check("yamlls schemaStore.enable false", yamlls.settings.yaml.schemaStore.enable == false)
local fake_client = { server_capabilities = { hoverProvider = true } }
vim.lsp.config.ruff.on_attach(fake_client)
check("ruff on_attach disables hover", fake_client.server_capabilities.hoverProvider == false)
local after_dir = vim.fn.stdpath("config") .. "/after"
check("rtp contains after/", vim.tbl_contains(vim.api.nvim_list_runtime_paths(), after_dir))

-- buffer-local description of a map, or nil
local function buf_desc(buf, lhs, mode)
  return vim.api.nvim_buf_call(buf, function()
    local m = vim.fn.maparg(lhs, mode, false, true)
    return m.buffer == 1 and m.desc or nil
  end)
end

local lsp_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_exec_autocmds("LspAttach", { buffer = lsp_buf, data = { client_id = -1 } })
check("LspAttach gd", buf_desc(lsp_buf, "gd", "n") == "LSP: Definition")
check("LspAttach gD", buf_desc(lsp_buf, "gD", "n") == "LSP: Declaration")
check("LspAttach <leader>ca n", buf_desc(lsp_buf, "<leader>ca", "n") == "LSP: Code action")
check("LspAttach <leader>ca x", buf_desc(lsp_buf, "<leader>ca", "x") == "LSP: Code action")

-- lazy keys (lhs, mode, desc)
local keys = {
  { "<leader>xx", "n", "Diagnostics (workspace)" },
  { "<leader>xX", "n", "Diagnostics (buffer)" },
  { "<leader>xs", "n", "Symbols" },
  { "<leader>xr", "n", "LSP references / definitions" },
  { "<leader>xq", "n", "Quickfix list" },
  { "<leader>sr", "n", "Search and replace (project)" },
  { "<leader>sr", "x", "Search and replace (selection)" },
  { "<leader>Db", "n", "Toggle breakpoint" },
  { "<leader>Dc", "n", "Continue / start" },
  { "<leader>Di", "n", "Step into" },
  { "<leader>Do", "n", "Step over" },
  { "<leader>DO", "n", "Step out" },
  { "<leader>Dr", "n", "Toggle REPL" },
  { "<leader>Dt", "n", "Terminate" },
  { "<leader>Du", "n", "Toggle debug UI" },
  { "<leader>tt", "n", "Run nearest test" },
  { "<leader>tf", "n", "Run file tests" },
  { "<leader>td", "n", "Debug nearest test" },
  { "<leader>ts", "n", "Toggle summary" },
  { "<leader>to", "n", "Show output" },
  { "<leader>tl", "n", "Run last test" },
  { "<leader>e", "n", "File explorer" },
  { "-", "n", "Open parent directory" },
  { "<leader>ff", "n", "Find files" },
  { "<leader>fg", "n", "Live grep" },
  { "<leader>fb", "n", "Buffers" },
  { "<leader>fh", "n", "Help" },
  { "<leader>fr", "n", "Recent files" },
  { "<leader>fd", "n", "Diagnostics" },
  { "<leader>fs", "n", "Document symbols" },
  { "<leader>fw", "n", "Grep word under cursor" },
  { "<leader>/", "n", "Search in buffer" },
  { "<M-h>", "n", "Go to left split/pane" },
  { "<M-j>", "n", "Go to lower split/pane" },
  { "<M-k>", "n", "Go to upper split/pane" },
  { "<M-l>", "n", "Go to right split/pane" },
  { "<leader>j", "n", "Easy jump" },
  { "<leader>j", "x", "Easy jump" },
  { "<leader>j", "o", "Easy jump" },
  { "<leader>J", "n", "Treesitter jump" },
  { "<leader>J", "x", "Treesitter jump" },
  { "<leader>J", "o", "Treesitter jump" },
  { "<leader>Ss", "n", "Restore session (cwd)" },
  { "<leader>Sl", "n", "Restore last session" },
  { "<leader>Sd", "n", "Don't save session" },
}
for _, k in ipairs(keys) do
  local got = vim.fn.maparg(k[1], k[2], false, true).desc
  check(("key %s [%s] desc: got %s, want %s"):format(k[1], k[2], tostring(got), k[3]), got == k[3])
end

-- gitsigns on_attach
local git_buf = vim.api.nvim_create_buf(false, true)
merged_opts("gitsigns.nvim").on_attach(git_buf)
local git_keys = {
  { "]h", "Git: Next hunk" },
  { "[h", "Git: Previous hunk" },
  { "<leader>gs", "Git: Stage/unstage hunk" },
  { "<leader>gr", "Git: Reset hunk" },
  { "<leader>gS", "Git: Stage buffer" },
  { "<leader>gp", "Git: Preview hunk" },
  { "<leader>gb", "Git: Blame line" },
  { "<leader>gB", "Git: Toggle line blame" },
}
for _, k in ipairs(git_keys) do
  check("gitsigns " .. k[1], buf_desc(git_buf, k[1], "n") == k[2])
end

-- core autocmds (last: ft=java loads nvim-jdtls, whose LspAttach hook rejects fake clients;
-- the jdtls launcher is stubbed so nothing starts)
package.loaded["ryanparker.java"] = { start = function() end }
vim.cmd("enew")
vim.bo.filetype = "java"
check("java shiftwidth", vim.bo.shiftwidth == 4)
check("java tabstop", vim.bo.tabstop == 4)
vim.cmd("enew")
vim.bo.filetype = "text"
check("text wrap", vim.wo.wrap == true)
check("text spell", vim.wo.spell == true)
package.loaded["ryanparker.java"] = nil

-- helpers
local filetypes = require("ryanparker.core.filetypes")
local expanded = filetypes.expand({ yaml = { "a" }, ["yaml.cloudformation"] = { "b" }, sh = { "s" } })
eq("expand keeps explicit member", expanded["yaml.cloudformation"], { "b" })
eq("expand fills bash", expanded.bash, { "s" })
check("expand members get distinct tables", expanded.sh ~= expanded.bash)
local fam = filetypes.family("sql")
fam[1] = "x"
eq("family returns a copy", filetypes.family("sql"), { "sql", "sql.dbt", "dbt" })
eq("parser_aliases", filetypes.parser_aliases, {
  ["sql.dbt"] = "sql",
  ["yaml.cloudformation"] = "yaml",
  ["terraform-vars"] = "terraform",
})

local keys = require("ryanparker.util.keys")
local seen = {}
package.loaded["smoke_probe"] = {
  sub = {
    f = function(...)
      local args = { ... }
      table.insert(seen, args)
      if #args > 0 then
        args[1].mutated = true
      end
      return select("#", ...), "r"
    end,
  },
}
local n0, r0 = keys.lazy_call("smoke_probe", "sub.f")()
check("lazy_call zero args", n0 == 0 and r0 == "r")
local call = keys.lazy_call("smoke_probe", "sub.f", { v = 1 })
call()
call()
check("lazy_call copies args per call", seen[3][1].mutated and seen[3][1] ~= seen[2][1] and seen[2][1].mutated)
local orig = { v = 1 }
keys.lazy_call("smoke_probe", "sub.f", orig)()
check("lazy_call does not mutate caller args", orig.mutated == nil)
package.loaded["smoke_probe"] = nil

local hbuf = vim.api.nvim_create_buf(false, true)
keys.buffer_mapper(hbuf, "Pre: ")("n", "<leader>zz", function() end, "Thing")
check("buffer_mapper desc prefix", buf_desc(hbuf, "<leader>zz", "n") == "Pre: Thing")

eq("mason.ensure shape", require("ryanparker.util.mason").ensure({ "a" }), {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  optional = true,
  opts_extend = { "ensure_installed" },
  opts = { ensure_installed = { "a" } },
})
local system = require("ryanparker.util.system")
check("system.run true", system.run({ "true" }) == "")
check("system.run false", system.run({ "false" }) == nil)
check("autocmd.augroup", type(require("ryanparker.util.autocmd").augroup("smoke")) == "number")

vim.fn.delete(tmp, "rf")

if #failures > 0 then
  print(#failures .. " smoke check(s) failed:")
  for _, f in ipairs(failures) do
    print(" - " .. f)
  end
  error("smoke test failed", 0)
end
print("smoke ok")
