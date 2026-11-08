local call = require("ryanparker.util.keys").lazy_call

return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (workspace)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Diagnostics (buffer)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<CR>", desc = "Symbols" },
      {
        "<leader>xr",
        "<cmd>Trouble lsp toggle focus=false win.position=right<CR>",
        desc = "LSP references / definitions",
      },
      { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = {},
    keys = {
      {
        "<leader>sr",
        function()
          require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
        end,
        desc = "Search and replace (project)",
      },
      {
        "<leader>sr",
        call("grug-far", "with_visual_selection"),
        mode = "x",
        desc = "Search and replace (selection)",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      {
        "<leader>Db",
        call("dap", "toggle_breakpoint"),
        desc = "Toggle breakpoint",
      },
      {
        "<leader>Dc",
        call("dap", "continue"),
        desc = "Continue / start",
      },
      {
        "<leader>Di",
        call("dap", "step_into"),
        desc = "Step into",
      },
      {
        "<leader>Do",
        call("dap", "step_over"),
        desc = "Step over",
      },
      {
        "<leader>DO",
        call("dap", "step_out"),
        desc = "Step out",
      },
      {
        "<leader>Dr",
        call("dap", "repl.toggle"),
        desc = "Toggle REPL",
      },
      {
        "<leader>Dt",
        call("dap", "terminate"),
        desc = "Terminate",
      },
      {
        "<leader>Du",
        call("dapui", "toggle"),
        desc = "Toggle debug UI",
      },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      require("dap-python").setup(vim.uv.fs_stat(debugpy) and debugpy or "python3")
    end,
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "rcasia/neotest-java",
    },
    keys = {
      {
        "<leader>tt",
        call("neotest", "run.run"),
        desc = "Run nearest test",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run file tests",
      },
      {
        "<leader>td",
        call("neotest", "run.run", { strategy = "dap" }),
        desc = "Debug nearest test",
      },
      {
        "<leader>ts",
        call("neotest", "summary.toggle"),
        desc = "Toggle summary",
      },
      {
        "<leader>to",
        call("neotest", "output.open", { enter = true }),
        desc = "Show output",
      },
      {
        "<leader>tl",
        call("neotest", "run.run_last"),
        desc = "Run last test",
      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python"),
          require("neotest-java"),
        },
      })
    end,
  },
  require("ryanparker.util.mason").ensure({ "debugpy" }),
}
