local M = {}

function M.ensure(tools)
  return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    optional = true,
    opts_extend = { "ensure_installed" },
    opts = { ensure_installed = tools },
  }
end

return M
