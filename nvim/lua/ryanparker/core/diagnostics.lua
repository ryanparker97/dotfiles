vim.diagnostic.config({
  underline = true,
  virtual_text = { current_line = true },
  severity_sort = true,
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
    end,
  },
  float = { border = "rounded", source = true },
})
