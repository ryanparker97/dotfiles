local M = {}

function M.setup()
  -- Filetype hints for SRE/data files that Neovim cannot always infer.
  vim.filetype.add({
    extension = {
      -- Built-in detection returns "tf" for empty or comment-only files, so new
      -- Terraform buffers would miss the terraform formatters/LSP until reopened.
      tf = "terraform",
    },
    pattern = {
      [".*%.ya?ml"] = {
        function(path, bufnr)
          local lines
          if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)
          elseif path and vim.fn.filereadable(path) == 1 then
            lines = vim.fn.readfile(path, "", 50)
          end
          for _, line in ipairs(lines or {}) do
            if line:find("AWSTemplateFormatVersion", 1, true) or line:find("AWS::", 1, true) then
              return "yaml.cloudformation"
            end
          end
        end,
      },
      [".*%.sql"] = {
        function(path)
          if not path then
            return nil
          end
          for _, dir in ipairs({ "models", "macros", "analyses", "seeds", "snapshots", "tests" }) do
            if path:find("/" .. dir .. "/", 1, true) then
              if vim.fs.root(path, "dbt_project.yml") then
                return "sql.dbt"
              end
              return nil
            end
          end
        end,
      },
    },
  })
end

local families = {
  sql = { "sql", "sql.dbt", "dbt" },
  yaml = { "yaml", "yaml.cloudformation" },
  terraform = { "terraform", "terraform-vars", "hcl" },
  sh = { "sh", "bash" },
  javascript = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
}

function M.family(name)
  return vim.deepcopy(families[name])
end

M.parser_aliases = { ["sql.dbt"] = "sql", ["yaml.cloudformation"] = "yaml", ["terraform-vars"] = "terraform" }

-- A key naming a family also fills every member that has no explicit entry
-- (each with its own copy of the value); explicit entries always win.
function M.expand(by_ft)
  local out = vim.deepcopy(by_ft)
  for key, value in pairs(by_ft) do
    for _, ft in ipairs(families[key] or {}) do
      if by_ft[ft] == nil then
        out[ft] = vim.deepcopy(value)
      end
    end
  end
  return out
end

return M
