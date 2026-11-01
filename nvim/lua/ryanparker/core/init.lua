vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw before plugins load. oil.nvim is the file browser.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- No remote plugins: silence the optional provider health checks
for _, p in ipairs({ "node", "perl", "python3", "ruby" }) do
  vim.g["loaded_" .. p .. "_provider"] = 0
end

require("ryanparker.core.options")
require("ryanparker.core.keymaps")
require("ryanparker.core.autocmds")
