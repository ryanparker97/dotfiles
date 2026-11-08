local M = {}

function M.lazy_call(module, path, ...)
  local args = vim.F.pack_len(...)
  return function()
    local fn = require(module)
    for part in path:gmatch("[^.]+") do
      fn = fn[part]
    end
    local copy = vim.deepcopy(args)
    return fn(vim.F.unpack_len(copy))
  end
end

function M.buffer_mapper(bufnr, prefix)
  return function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = prefix .. desc })
  end
end

return M
