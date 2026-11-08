-- Java is special: use nvim-jdtls instead of generic lspconfig auto-enable.
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
require("ryanparker.java").start()
