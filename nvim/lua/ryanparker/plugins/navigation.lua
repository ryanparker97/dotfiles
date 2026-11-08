local call = require("ryanparker.util.keys").lazy_call

return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    keys = {
      {
        "<leader>e",
        call("oil", "toggle_float"),
        desc = "File explorer",
      },
      {
        "-",
        call("oil", "open"),
        desc = "Open parent directory",
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      skip_confirm_for_simple_edits = true,
      view_options = { show_hidden = true },
      float = {
        padding = 2,
        max_width = 0.85,
        max_height = 0.85,
        border = "rounded",
        override = function(conf)
          local width = math.min(conf.width or 100, math.max(40, vim.o.columns - 4))
          local height = math.min(conf.height or 30, math.max(10, vim.o.lines - 6))
          conf.width = width
          conf.height = height
          conf.row = math.floor((vim.o.lines - height) / 2 - 1)
          conf.col = math.floor((vim.o.columns - width) / 2)
          return conf
        end,
      },
      keymaps = {
        ["<CR>"] = "actions.select",
        ["q"] = "actions.close",
        ["<C-s>"] = "actions.select_split",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-t>"] = "actions.select_tab",
        ["<C-h>"] = false,
        ["<C-l>"] = false,
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = vim.fn.executable("make") == 1,
      },
    },
    keys = {
      {
        "<leader>ff",
        call("telescope.builtin", "find_files"),
        desc = "Find files",
      },
      {
        "<leader>fg",
        call("telescope.builtin", "live_grep"),
        desc = "Live grep",
      },
      {
        "<leader>fb",
        call("telescope.builtin", "buffers"),
        desc = "Buffers",
      },
      {
        "<leader>fh",
        call("telescope.builtin", "help_tags"),
        desc = "Help",
      },
      {
        "<leader>fr",
        call("telescope.builtin", "oldfiles"),
        desc = "Recent files",
      },
      {
        "<leader>fd",
        call("telescope.builtin", "diagnostics"),
        desc = "Diagnostics",
      },
      {
        "<leader>fs",
        call("telescope.builtin", "lsp_document_symbols"),
        desc = "Document symbols",
      },
      {
        "<leader>fw",
        call("telescope.builtin", "grep_string"),
        desc = "Grep word under cursor",
      },
      {
        "<leader>/",
        call("telescope.builtin", "current_buffer_fuzzy_find"),
        desc = "Search in buffer",
      },
    },
    opts = function()
      local actions = require("telescope.actions")
      return {
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "➜ ",
          mappings = {
            i = {
              ["<Esc>"] = actions.close,
            },
          },
        },
      }
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      pcall(telescope.load_extension, "fzf")
    end,
  },

  {
    -- Same <M-h/j/k/l> keys as tmux; at the edge of the Neovim layout it moves to
    -- the neighbouring tmux pane (see the is_vim binds in tmux/tmux.conf).
    "mrjones2014/smart-splits.nvim",
    lazy = false, -- the tmux backend marks the pane (@pane-is-vim) at startup; do not lazy load
    dependencies = {
      -- smart-splits v3 ships no multiplexer support. Without this backend the
      -- <M-h/j/k/l> keys stop at the edge of the Neovim layout.
      { "smart-splits-nvim/backend-tmux", main = "smart-splits-backend-tmux" },
    },
    opts = {
      mux = { backend = "smart-splits-backend-tmux" },
    },
    keys = {
      {
        "<M-h>",
        call("smart-splits", "move_cursor_left"),
        desc = "Go to left split/pane",
      },
      {
        "<M-j>",
        call("smart-splits", "move_cursor_down"),
        desc = "Go to lower split/pane",
      },
      {
        "<M-k>",
        call("smart-splits", "move_cursor_up"),
        desc = "Go to upper split/pane",
      },
      {
        "<M-l>",
        call("smart-splits", "move_cursor_right"),
        desc = "Go to right split/pane",
      },
    },
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>j",
        call("flash", "jump"),
        mode = { "n", "x", "o" },
        desc = "Easy jump",
      },
      {
        "<leader>J",
        call("flash", "treesitter"),
        mode = { "n", "x", "o" },
        desc = "Treesitter jump",
      },
    },
  },
}
