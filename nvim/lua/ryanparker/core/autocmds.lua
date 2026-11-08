local augroup = require("ryanparker.util.autocmd").augroup("core")

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.hl.on_yank({ timeout = 180 })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Restore the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" or vim.bo[ev.buf].filetype:match("^git") then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Reload files changed outside Neovim (git checkout, formatters, other panes).
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup,
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Keep splits equal when the terminal is resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})

-- Create missing parent directories on save.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

-- Close throwaway buffers with just `q`.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true, desc = "Close window" })
  end,
})
