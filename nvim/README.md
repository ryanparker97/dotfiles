# Neovim setup

A small Lua config for a mix of **web development**, **data engineering**, and **SRE** work: Java, Python, dbt/SQL, Terraform/HCL, Bash, CloudFormation/YAML, JSON, Docker, and frontend files.

Requires Neovim 0.12+ (uses `vim.lsp.config`, `pumborder`, built-in `nvim.undotree`). `refactoring.nvim` needs 0.12.5+ and is skipped on older builds.

## Research choices

- Neovim 0.12 supports the modern native LSP path: `vim.lsp.config()`, and `mason-lspconfig`'s `automatic_enable` calls `vim.lsp.enable` for installed servers, with `jdtls` excluded.
- Java works best through `nvim-jdtls`, so `jdtls` is installed by Mason but excluded from generic LSP auto-enable.
- `conform.nvim` keeps formatting lightweight; `nvim-lint` complements LSP diagnostics for CLIs like `shellcheck`, `sqlfluff`, `tflint`, and `cfn-lint`.
- Debugging uses `nvim-dap`: Python via `nvim-dap-python` + Mason `debugpy`; Java via jdtls bundles from Mason `java-debug-adapter` and `java-test`, used only when present.
- `neotest` runs tests with the python and java adapters.
- `snacks.nvim` is limited to notifier, indent and lazygit; telescope stays the picker.
- Dedicated UX plugins provide the file explorer (`oil.nvim`), pickers (`telescope.nvim`), pairs (`nvim-autopairs`), surround operations (`nvim-surround`), icons (`nvim-web-devicons`), and statusline (`lualine.nvim`).

## Install host tools on macOS

```sh
brew install neovim git curl ripgrep fd tree-sitter node python pipx openjdk terraform shellcheck shfmt tflint cfn-lint lazygit
pipx install dbt-core
pipx install sqlfluff
```

A C compiler (`xcode-select --install`) is needed for treesitter parsers and `telescope-fzf-native` (`make`). terraform, shellcheck, shfmt, tflint and cfn-lint are also installed by Mason, so the brew copies are optional.

Optional Java build tools:

```sh
brew install maven gradle
```

## Java prerequisites

Requires JDK 21+. jdtls needs a real JDK (the `/usr/bin/java` stub is not enough):

```sh
brew install openjdk
export JAVA_HOME="$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home"
sudo ln -sfn "$(brew --prefix openjdk)/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk
```

`jdtls` is installed by mason-lspconfig (`ensure_installed`); `java-debug-adapter` and `java-test` are installed by mason-tool-installer. Install manually from Neovim with:

```vim
:MasonInstall jdtls java-debug-adapter java-test
```

Hot code replace is set up automatically when the debug bundles are present, so debugging works only after the Mason packages are installed.

For Java tests, run `:NeotestJava setup` once (downloads the JUnit jar).

## Plugin layout

Plugins live in `lua/ryanparker/plugins/*.lua`, one file per topic, imported by `lazy.lua`:

| File | Contents |
| --- | --- |
| `ui.lua` | catppuccin, lualine, which-key, persistence, devicons |
| `navigation.lua` | oil, telescope + fzf-native, smart-splits + tmux backend, flash |
| `editing.lua` | autopairs, surround, plenary |
| `git.lua` | gitsigns, diffview |
| `lsp.lua` | mason, mason-lspconfig, mason-tool-installer, lspconfig, nvim-jdtls, schemastore, lazydev |
| `completion.lua` | blink.cmp, snippets, dadbod source for sql and dbt |
| `formatting.lua` | conform.nvim |
| `linting.lua` | nvim-lint |
| `treesitter.lua` | treesitter parsers |
| `data.lua` | dbtpal, vim-dadbod, dadbod-ui, markview (markdown rendering) |
| `dev.lua` | trouble, grug-far, nvim-dap + dap-ui + dap-python, neotest + python/java adapters |
| `extras.lua` | quicker, treesitter-context, todo-comments, snacks, refactoring, yaml.nvim, overseer |
| `java.lua` | the jdtls launcher, started from `ftplugin/java.lua` |

## Mason-managed tools

Open Neovim and run:

```vim
:Lazy restore
:Mason
```

`:Lazy restore` installs the versions pinned in `lazy-lock.json`; `:Lazy sync` updates them. mason-tool-installer installs the tool list on the first interactive start.

Mason installs LSP servers and CLI tools such as `basedpyright`, `ruff`, `jdtls`, `terraform`, `terraformls`, `bashls`, `yamlls`, `jsonls`, `prettier`, `sqlfluff`, `shellcheck`, `shfmt`, `tflint`, `cfn-lint`, `debugpy`, `java-debug-adapter`, `java-test`, `stylua`, `eslint_d`, `hadolint`, `markdownlint-cli2`, `yamllint` and `actionlint` where available. `sqlfluff` is only added on Python 3.10+.

## Keymaps

Leader is `<Space>`.

### General

| Key | Action |
| --- | --- |
| `<Esc>` | clear search highlight |
| `<leader>w` / `<leader>q` | save / quit window |
| `<leader>bd` / `<leader>bo` | close buffer / close other buffers |
| `<S-h>` / `<S-l>` | previous / next buffer |
| `<leader>W` | `<C-w>` window commands (which-key proxy) |
| `<leader>ur` | redraw / clear highlights |
| `<leader>uu` | undo tree (built-in) |
| `<leader>un` | notification history |
| `<leader>uc` | toggle code context |
| `<leader>Ss`, `<leader>Sl`, `<leader>Sd` | session: restore / last / don't save |
| `<Esc><Esc>` | exit terminal mode (terminal) |
| `<C-a>` / `<C-e>` | start / end of line (insert) |

### Editing

| Key | Action |
| --- | --- |
| `<` / `>` | outdent / indent, keep selection (visual) |
| `J` / `K` | move selection down / up (visual) |
| `<leader>p` | paste without clobbering register (visual) |
| `<C-d>`, `<C-u>`, `n`, `N` | centered half page / search jumps |
| `sa`, `saa`, `sA`, `sAA` | add surround (normal) |
| `sa`, `sA` | add surround / linewise (visual) |
| `sd`, `sr`, `sR` | delete / replace / replace linewise surround |

### Find

| Key | Action |
| --- | --- |
| `<leader>e` | file explorer |
| `-` | parent directory (oil) |
| `<leader>ff`, `<leader>fg`, `<leader>fb`, `<leader>fh` | find files / live grep / buffers / help |
| `<leader>fr`, `<leader>fd`, `<leader>fs`, `<leader>fw` | recent files / diagnostics / document symbols / grep word |
| `<leader>ft` | todos |
| `<leader>/` | fuzzy find in current buffer |
| `<leader>j` / `<leader>J` | flash jump / treesitter jump (n, x, o) |
| `<leader>sr` | search and replace with grug-far (n: word, x: selection) |

### Code / LSP

| Key | Action |
| --- | --- |
| `gd`, `gD` | definition, declaration |
| `<leader>ca` | LSP code action |
| `K`, `grr`, `gri`, `grn`, `gra`, `grt`, `grx`, `gO` | hover, references, implementation, rename, code action, type definition, run codelens, symbols (Neovim built-ins) |
| `<C-s>` | signature help (insert, built-in) |
| `<leader>cf` | format buffer/range |
| `<leader>cd` / `<leader>cl` | line diagnostics / diagnostic loclist |
| `<leader>cr` | refactoring (0.12.5+) |
| `<leader>cy` | yank YAML key path (YAML files) |
| `]d` / `[d` | next / previous diagnostic (built-in, opens float) |
| `]t` / `[t` | next / previous todo comment |

### Diagnostics (trouble)

| Key | Action |
| --- | --- |
| `<leader>xx` / `<leader>xX` | workspace / buffer diagnostics |
| `<leader>xs` | symbols |
| `<leader>xr` | LSP references |
| `<leader>xq` | quickfix list |

### Git

| Key | Action |
| --- | --- |
| `]h` / `[h` | next / previous git hunk |
| `<leader>gs`, `<leader>gr`, `<leader>gS` | stage / reset hunk / stage buffer |
| `<leader>gp`, `<leader>gb`, `<leader>gB` | preview hunk / blame line / toggle line blame |
| `<leader>gd` / `<leader>gh` | diffview / file history |
| `<leader>gg` | lazygit |

### Debug

| Key | Action |
| --- | --- |
| `<leader>Db`, `<leader>Dc`, `<leader>Di`, `<leader>Do`, `<leader>DO`, `<leader>Dr`, `<leader>Dt`, `<leader>Du` | breakpoint / continue / step into / step over / step out / REPL / terminate / DAP UI |

### Test

| Key | Action |
| --- | --- |
| `<leader>tt`, `<leader>tf`, `<leader>td`, `<leader>ts`, `<leader>to`, `<leader>tl` | run nearest / run file / debug nearest / summary / output / run last |

### Tasks

| Key | Action |
| --- | --- |
| `<leader>or` / `<leader>ot` | run task / task list (overseer) |

### Data

| Key | Action |
| --- | --- |
| `<leader>dr`, `<leader>dt`, `<leader>db`, `<leader>dc`, `<leader>dD` | dbt run/test/build/compile/debug when `dbt` exists |
| `<leader>du` | database UI |

### Panes

| Key | Action |
| --- | --- |
| `<M-h/j/k/l>` | move between splits, then tmux panes (smart-splits) |

## Language coverage

| Area | LSP | Format | Lint | Debug / Test |
| --- | --- | --- | --- | --- |
| Java | `jdtls` via `nvim-jdtls` | jdtls fallback | jdtls diagnostics | java-debug + neotest-java |
| Python | `basedpyright` + `ruff` | `ruff` (organize imports + format) | `ruff` diagnostics | debugpy + neotest-python |
| dbt/SQL | — | `sqlfluff` | `sqlfluff` | completion via dadbod (needs `b:db`/`g:db`/`$DATABASE_URL` or DBUI) |
| Terraform/HCL | `terraformls` | `terraform fmt` | `tflint` | — |
| Bash | `bashls` | `shfmt` | `shellcheck` | — |
| YAML | `yamlls` + SchemaStore | `prettier` | `yamllint` | — |
| CloudFormation | `yamlls` + CFN tags | `prettier` | `cfn-lint` | — |
| GitHub Actions | `yamlls` | `prettier` | `actionlint` | — |
| Docker | `dockerls` | — | `hadolint` | — |
| Markdown | `marksman` | `prettier` | `markdownlint-cli2` | — |
| TOML | `taplo` | taplo (LSP fallback) | — | — |
| Lua | `lua_ls` + lazydev | `stylua` | — | — |
| Web/JSON | `vtsls`, `html`, `cssls`, `tailwindcss`, `emmet_ls`, `jsonls` | `prettier` | `eslint_d` | — |

`w:db` and `t:db` are also accepted for dadbod completion. `:DBCompletionClearCache` also resets dbt priming, so run it after a schema change.

## Health check

Run `:checkhealth`. Remaining warnings and errors the config cannot fix are expected:

- snacks modules reported `{disabled}`
- snacks image tools (kitty/magick/gs/mmdc/tectonic)
- "Nvim 0.12.6 is available" (update notice)
- the Snacks.picker `vim.ui.select` warning
- Snacks.image missing parsers (norg/scss/svelte/vue)
- smart-splits "`tmux -V` did not answer"
- tmux `$TERM` and smart-splits `@pane-is-vim`, which are tmux-side
- the empty `site/pack/core` directory
