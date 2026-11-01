return {
  {
    "stevearc/quicker.nvim",
    ft = "qf",
    opts = {},
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = { max_lines = 3 },
    keys = {
      { "<leader>uc", "<cmd>TSContext toggle<CR>", desc = "Toggle code context" },
    },
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>ft", "<cmd>TodoTelescope<CR>", desc = "Find todos" },
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous todo",
      },
    },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      -- Telescope stays the picker; only the non-overlapping modules are on.
      notifier = { enabled = true },
      indent = { enabled = true },
      lazygit = { enabled = true },
    },
    keys = {
      {
        "<leader>gg",
        function()
          Snacks.lazygit()
        end,
        desc = "Lazygit",
      },
      {
        "<leader>un",
        function()
          Snacks.notifier.show_history()
        end,
        desc = "Notification history",
      },
    },
  },

  {
    "ThePrimeagen/refactoring.nvim",
    -- Upstream requires 0.12.5 plus async.nvim on 0.12; on older builds the plugin is left out instead of erroring on <leader>cr.
    enabled = function()
      return vim.fn.has("nvim-0.12.5") == 1
    end,
    dependencies = { "lewis6991/async.nvim", "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    keys = {
      {
        "<leader>cr",
        function()
          require("refactoring").select_refactor()
        end,
        mode = { "n", "x" },
        desc = "Refactor",
      },
    },
  },

  {
    "cuducos/yaml.nvim",
    ft = { "yaml", "yaml.cloudformation" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    keys = {
      { "<leader>cy", "<cmd>YAMLYank<CR>", ft = { "yaml", "yaml.cloudformation" }, desc = "Yank YAML key path" },
    },
  },

  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerTaskAction" },
    opts = {},
    keys = {
      { "<leader>or", "<cmd>OverseerRun<CR>", desc = "Run task" },
      { "<leader>ot", "<cmd>OverseerToggle<CR>", desc = "Task list" },
    },
  },
}
