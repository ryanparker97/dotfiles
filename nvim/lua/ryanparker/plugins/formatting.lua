return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "v" },
        desc = "Format",
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
      formatters_by_ft = require("ryanparker.core.filetypes").expand({
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        javascript = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        sh = { "shfmt" },
        sql = { "sqlfluff" },
        terraform = { "terraform_fmt" },
      }),
    },
  },
  require("ryanparker.util.mason").ensure({ "stylua", "prettier", "shfmt", "ruff", "sqlfluff", "terraform" }),
}
