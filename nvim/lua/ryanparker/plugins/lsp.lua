local lsp_servers = {
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
}

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
      "b0o/schemastore.nvim",
    },
    config = function()
      -- Per-server settings live in after/lsp/<name>.lua.
      vim.lsp.config("*", { capabilities = require("ryanparker.lsp.capabilities").get() })
      require("ryanparker.lsp.attach").setup()

      require("mason-lspconfig").setup({
        ensure_installed = lsp_servers,
        automatic_enable = { exclude = { "jdtls" } },
      })
    end,
  },

  { "b0o/schemastore.nvim", lazy = true },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}
