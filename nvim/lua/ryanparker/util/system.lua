local M = {}

function M.run(cmd)
  local ok, res = pcall(vim.system, cmd, { text = true })
  if not ok then
    return nil
  end
  local out = res:wait()
  if out.code ~= 0 then
    return nil
  end
  return vim.trim(out.stdout or "")
end

return M
