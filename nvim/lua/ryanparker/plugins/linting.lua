return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      linters_by_ft = require("ryanparker.core.filetypes").expand({
        javascript = { "eslint_d" },
        sh = { "shellcheck" },
        dockerfile = { "hadolint" },
        sql = { "sqlfluff" },
        terraform = { "tflint" },
        markdown = { "markdownlint-cli2" },
        yaml = { "yamllint" },
        ["yaml.cloudformation"] = { "cfn_lint" },
      }),
    },
    config = function(_, opts)
      local lint = require("lint")
      lint.linters_by_ft = opts.linters_by_ft

      -- Slow linters: never run while typing (InsertLeave).
      local slow = { sqlfluff = true }

      -- Per-linter availability cache: only hits are cached, so tools installed mid-session are picked up.
      local availability = {}

      local function resolve_linter(name)
        local linter = lint.linters[name]
        if type(linter) == "function" then
          local ok, resolved = pcall(linter)
          if not ok then
            return nil
          end
          linter = resolved
        end
        return linter
      end

      local function linter_is_available(name)
        if availability[name] then
          return true
        end
        local available = false
        local linter = resolve_linter(name)
        if linter then
          local cmd = linter.cmd
          if type(cmd) == "function" then
            local ok, resolved = pcall(cmd)
            cmd = ok and resolved or nil
          end
          available = type(cmd) == "string" and vim.fn.executable(cmd) == 1
        end
        if available then
          availability[name] = true
        end
        return available
      end

      local function linters_for(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == "yaml" and vim.api.nvim_buf_get_name(bufnr):find("/%.github/workflows/") then
          return { "actionlint" }
        end
        return lint.linters_by_ft[ft]
      end

      local function try_lint(bufnr, opts)
        local names = linters_for(bufnr)
        if not names then
          return
        end
        local available = vim.tbl_filter(function(name)
          if opts and opts.skip_slow and slow[name] then
            return false
          end
          return linter_is_available(name)
        end, names)
        if vim.tbl_isempty(available) then
          return
        end
        lint.try_lint(available)
      end

      local group = require("ryanparker.util.autocmd").augroup("lint")
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        group = group,
        callback = function(args)
          try_lint(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        callback = function(args)
          try_lint(args.buf, { skip_slow = true })
        end,
      })
    end,
  },
  require("ryanparker.util.mason").ensure({
    "shellcheck",
    "eslint_d",
    "hadolint",
    "tflint",
    "cfn-lint",
    "sqlfluff",
    "markdownlint-cli2",
    "yamllint",
    "actionlint",
  }),
}
