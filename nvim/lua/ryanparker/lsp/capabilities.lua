local M = {}

function M.get(base)
  local ok, blink = pcall(require, "blink.cmp")
  if ok and blink.get_lsp_capabilities then
    return blink.get_lsp_capabilities(base)
  end
  return base or {}
end

return M
