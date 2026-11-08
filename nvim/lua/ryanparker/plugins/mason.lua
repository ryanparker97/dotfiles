local python_310 -- cached result of has_python_310()

-- Spawns python3 once, on first call; only invoked when mason-tool-installer loads.
local function has_python_310()
  if python_310 ~= nil then
    return python_310
  end
  python_310 = false
  if vim.fn.executable("python3") == 0 then
    return python_310
  end
  local version = require("ryanparker.util.system").run({
    "python3",
    "-c",
    "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')",
  })
  if not version then
    return python_310
  end
  local major, minor = version:match("^(%d+)%.(%d+)")
  major, minor = tonumber(major), tonumber(minor)
  python_310 = (major and minor and (major > 3 or (major == 3 and minor >= 10))) and true or false
  return python_310
end

return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = { ui = { border = "rounded" } },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {},
      run_on_start = true,
    },
    config = function(_, opts)
      local seen, tools = {}, {}
      for _, tool in ipairs(opts.ensure_installed) do
        if not seen[tool] and (tool ~= "sqlfluff" or has_python_310()) then
          seen[tool] = true
          table.insert(tools, tool)
        end
      end
      opts.ensure_installed = tools

      local installer = require("mason-tool-installer")
      installer.setup(opts)
      -- The plugin's own start hook listens for VimEnter, which has already fired
      -- by the time a VeryLazy load happens.
      installer.run_on_start()
    end,
  },
}
