local dadbod_fts = { sql = true, mysql = true, plsql = true, ["sql.dbt"] = true }

-- vim-dadbod-completion hard-codes ['sql','mysql','plsql'] in fetch(), but once a
-- buffer is cached, omni() no longer checks the filetype. So prime dbt buffers by
-- briefly presenting them as sql. eventignore=all keeps FileType, ftplugin and
-- syntax from re-running during the swap.
local function prime_dbt(buf)
  local url
  -- Explicit n: the list has nil holes, which ipairs would stop at.
  local cands = { vim.w.db, vim.t.db, vim.b[buf].db, vim.g.db, vim.env.DATABASE_URL, n = 5 }
  for i = 1, cands.n do
    local v = cands[i]
    if v and v ~= "" then
      url = v
      break
    end
  end
  if not url or vim.b[buf].dadbod_primed == tostring(url) then
    return
  end
  vim.b[buf].dadbod_primed = tostring(url)
  local saved = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.bo[buf].filetype = "sql"
  pcall(vim.fn["vim_dadbod_completion#fetch"], buf)
  vim.bo[buf].filetype = "sql.dbt"
  vim.o.eventignore = saved
end

local function dadbod_enabled()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  if not dadbod_fts[ft] then
    return false
  end
  if ft == "sql.dbt" then
    prime_dbt(buf)
  end
  return true
end

return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
      {
        "kristijanhusak/vim-dadbod-completion",
        dependencies = { "tpope/vim-dadbod" },
        config = function()
          -- The stock command leaves primed dbt buffers stale; also reset their priming.
          vim.api.nvim_create_user_command("DBCompletionClearCache", function()
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_loaded(b) then
                vim.b[b].dadbod_primed = nil
              end
            end
            vim.fn["vim_dadbod_completion#clear_cache"]()
          end, { force = true, desc = "Clear dadbod completion cache (and dbt priming)" })
        end,
      },
    },
    opts = {
      keymap = { preset = "enter" },
      signature = { enabled = true },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 } },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          lua = { inherit_defaults = true, "lazydev" },
          -- blink splits "sql.dbt" on ".", so this entry also serves dbt models.
          sql = { "snippets", "dadbod", "buffer" },
          mysql = { "snippets", "dadbod", "buffer" },
          plsql = { "snippets", "dadbod", "buffer" },
        },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink", enabled = dadbod_enabled },
        },
      },
    },
  },
}
