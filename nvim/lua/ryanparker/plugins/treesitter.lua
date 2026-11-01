return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "lua",
        "luadoc",
        "vim",
        "vimdoc",
        "bash",
        "python",
        "sql",
        "java",
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "json",
        "yaml",
        "toml",
        "dockerfile",
        "terraform",
        "hcl",
        "markdown",
        "markdown_inline",
        "regex",
      }
      local function install_missing()
        local installed = require("nvim-treesitter").get_installed("parsers")
        local missing = vim.tbl_filter(function(p)
          return not vim.list_contains(installed, p)
        end, parsers)
        if #missing == 0 then
          return
        end
        if vim.fn.executable("tree-sitter") ~= 1 then
          vim.notify("Install tree-sitter CLI for parser install/update: brew install tree-sitter", vim.log.levels.WARN)
          return
        end
        require("nvim-treesitter").install(missing)
      end
      vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = install_missing })
      pcall(vim.treesitter.language.register, "sql", "sql.dbt")
      pcall(vim.treesitter.language.register, "yaml", "yaml.cloudformation")
      pcall(vim.treesitter.language.register, "terraform", "terraform-vars")

      local function start(buf)
        local ft = vim.bo[buf].filetype
        if ft == "" then
          return
        end
        local lang = vim.treesitter.language.get_lang(ft) or ft
        if pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(args)
          start(args.buf)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          start(buf)
        end
      end
    end,
  },
}
