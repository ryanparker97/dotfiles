return {
  { "nvim-tree/nvim-web-devicons", lazy = true },

  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = { which_key = true, gitsigns = true, treesitter = true },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      {
        "<leader>Ss",
        function()
          require("persistence").load()
        end,
        desc = "Restore session (cwd)",
      },
      {
        "<leader>Sl",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>Sd",
        function()
          require("persistence").stop()
        end,
        desc = "Don't save session",
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local function lsp_clients()
        local names = {}
        for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
          names[#names + 1] = c.name
        end
        return #names > 0 and (" " .. table.concat(names, ", ")) or ""
      end

      return {
        options = {
          theme = "auto",
          globalstatus = true,
          component_separators = { left = "\u{e0b5}", right = "\u{e0b7}" },
          section_separators = { left = "\u{e0b4}", right = "\u{e0b6}" },
          disabled_filetypes = { statusline = { "dashboard", "alpha", "snacks_dashboard" } },
        },
        sections = {
          lualine_a = {
            { "mode", separator = { left = "\u{e0b6}" }, right_padding = 2 },
          },
          lualine_b = {
            { "branch", icon = "" },
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
            },
          },
          lualine_c = {
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = "󰌵 " },
            },
          },
          lualine_x = {
            { lsp_clients, color = { gui = "italic" } },
            {
              "encoding",
              cond = function()
                return vim.bo.fileencoding ~= "utf-8"
              end,
            },
            { "fileformat", symbols = { unix = "", dos = "", mac = "" } },
          },
          lualine_y = { { "progress" } },
          lualine_z = {
            { "location", separator = { right = "\u{e0b4}" }, left_padding = 2 },
          },
        },
        inactive_sections = {
          lualine_c = { "filename" },
          lualine_x = { "location" },
        },
      }
    end,
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = 0,
      triggers = {
        { "<leader>", mode = { "n", "v" } },
        { "<localleader>", mode = { "n", "v" } },
      },
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "data / db" },
        { "<leader>D", group = "debug" },
        { "<leader>t", group = "test" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>o", group = "tasks" },
        { "<leader>s", group = "find and replace" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>u", group = "ui" },
        { "<leader>W", proxy = "<C-w>", group = "window" },
        { "<leader>q", desc = "Quit window" },
        { "<leader>S", group = "session" },
        { "<leader>w", desc = "Save file" },
        { "<leader>bd", desc = "Close buffer" },
      },
    },
  },
}
