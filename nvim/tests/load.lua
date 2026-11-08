-- Usage: nvim --clean -l tests/load.lua <module-or-file.lua>...
-- Loads each module (or .lua file) without the user config; errors exit 1.
local cwd = vim.uv.cwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. package.path
vim.opt.rtp:prepend(cwd)

for i = 1, #arg do
  local name = arg[i]
  if name:match("%.lua$") then
    local result = dofile(name)
    if name:find("after/lsp/", 1, true) then
      assert(type(result) == "table", name .. " must return a table")
    end
  else
    require(name)
  end
  print("ok " .. name)
end
