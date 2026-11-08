local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = require("ryanparker.util.autocmd").augroup("lsp_attach"),
    callback = function(event)
      local map = require("ryanparker.util.keys").buffer_mapper(event.buf, "LSP: ")
      -- Built-ins (0.11+): K hover, grr references, gri implementation,
      -- grn rename, gra code action, gO document symbols.
      map("n", "gd", vim.lsp.buf.definition, "Definition")
      map("n", "gD", vim.lsp.buf.declaration, "Declaration")
      map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })
end

return M
