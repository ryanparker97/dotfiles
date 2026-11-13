# dotfiles

Personal configuration for zsh (Oh My Zsh + Starship), alacritty, tmux, nvim, yabai, skhd, and karabiner.

## Install

```sh
./install.sh
```

Symlinks each config into `$HOME` / `${XDG_CONFIG_HOME:-~/.config}`. It is idempotent: correct links are left alone, and anything else in the way is moved to `<path>.bak.<timestamp>`.

Prerequisites: [Oh My Zsh](https://ohmyz.sh/) at `~/.oh-my-zsh` (not installed automatically), plus starship, fzf, zoxide, tmux, and a Nerd Font (FiraCode).

Do not set `ZDOTDIR`; see `zsh/README.md`.

## Keymaps

### zsh

| Key | Action |
| --- | --- |
| `Ctrl-F` | fzf file picker (no hidden files) |
| `Ctrl-G` | fzf cd widget |
| `Alt-,` | insert last word |
| `Home` / `End` | beginning / end of line |

Emacs keybindings are on (`bindkey -e`).

### tmux

Prefix is `Ctrl-A`. `M-` is Alt/Option and needs no prefix.

| Key | Action |
| --- | --- |
| `M-h/j/k/l` | move between panes (passes through to vim) |
| `M-,` `M-.` `M--` `M-=` | resize pane left / right / down / up |
| `M-p` / `M-n`, `M-H` / `M-L` | previous / next window |
| `M-1` … `M-9` | select window 1-9 |
| `M-w` / `M-S` | choose tree / choose session |
| `M-c` | new window (current path) |
| `M-s` / `M-v` | split horizontal / vertical (current path) |
| `M-z` | zoom pane |
| `M-r` | reload tmux config |
| `M-[` | enter copy mode (`v` begins selection) |
| `prefix h/j/k/l` | select pane left / down / up / right |
| `prefix s` / `prefix v` | split below / right (current path) |
| `prefix ,` `.` `-` `=` | resize pane left / right / down / up (repeatable) |
| `prefix H` / `prefix L` | previous / next window |
| `prefix Ctrl-C` | new window in `$HOME` |
| `prefix c` / `prefix x` | kill pane / swap pane down |
| `prefix z` | zoom pane |
| `prefix r` | rename window |
| `prefix R` | reload tmux config |
| `prefix Ctrl-A` | last window |
| `prefix w` / `prefix Ctrl-W` / `prefix "` | list / choose windows |
| `prefix S` | choose session |
| `prefix Ctrl-D` | detach |
| `prefix Ctrl-X` | lock server |
| `prefix *` | synchronize panes |
| `prefix P` | toggle pane border status |
| `prefix K` | clear screen |
| `prefix :` | command prompt |
| `prefix o` | sessionx session switcher |
| `prefix p` | floax floating pane |

### skhd (yabai)

`⌃⌥` = Control + Option held together (both left of the space bar on a MacBook; any keyboard works). Config: `skhd/skhdrc`. If nothing responds, run `skhd --reload`.

**Normal mode**

| Key | Action |
| --- | --- |
| `⌃⌥ h/j/k/l` | focus window west / south / north / east (falls through to the next display at the edge) |
| `⌃⌥ tab` | focus the previously used window |
| `⌃⌥ f` | toggle zoom-fullscreen |
| `⌃⌥ t` | toggle float (centered at 2/3 size) |
| `⌃⌥ b` | balance window sizes on this space |
| `⌃⌥ r` | rotate layout 90° |
| `⌃⌥ x` | toggle split direction |
| `⌃⌥ v` | mirror layout on the y-axis |
| `⌃⌥ a` / `⌃⌥ d` | stack / bsp layout |
| `⌃⌥ return` | new Alacritty window |
| `⌃⌥ 1`…`5` | go to Desktop chat / terminal / web / notes / default |
| `⌃⌥ m` / `⌃⌥ s` / `⌃⌥ e` | enter move / swap / resize mode |

**Inside a mode**: release `⌃⌥` and press the plain key. While a mode is on, skhd captures every key, so normal typing does nothing until you leave.

| Mode | Key | Action |
| --- | --- | --- |
| move | `h/j/k/l` | move the window west / south / north / east within the space, then exit |
| move | `1`…`5` | send the window to chat / terminal / web / notes / default without following it, then exit (may fail on macOS 27) |
| move | `m` / `esc` | leave without doing anything |
| swap | `h/j/k/l` | swap with the neighbour in that direction, then exit |
| swap | `s` / `esc` | leave |
| resize | `h` / `j` / `k` / `l` | grow left / down / up / right by 60 px (shrinks the opposite edge at the screen edge); stays on |
| resize | `e` / `esc` | leave |

### Neovim

Leader is `<Space>`.

#### General

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

#### Editing

| Key | Action |
| --- | --- |
| `<` / `>` | outdent / indent, keep selection (visual) |
| `J` / `K` | move selection down / up (visual) |
| `<leader>p` | paste without clobbering register (visual) |
| `<C-d>`, `<C-u>`, `n`, `N` | centered half page / search jumps |
| `sa`, `saa`, `sA`, `sAA` | add surround (normal) |
| `sa`, `sA` | add surround / linewise (visual) |
| `sd`, `sr`, `sR` | delete / replace / replace linewise surround |

#### Find

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

#### Code / LSP

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
| `<leader>mp` | toggle markdown preview in browser, renders mermaid (markdown files) |
| `]d` / `[d` | next / previous diagnostic (built-in, opens float) |
| `]t` / `[t` | next / previous todo comment |

#### Diagnostics (trouble)

| Key | Action |
| --- | --- |
| `<leader>xx` / `<leader>xX` | workspace / buffer diagnostics |
| `<leader>xs` | symbols |
| `<leader>xr` | LSP references |
| `<leader>xq` | quickfix list |

#### Git

| Key | Action |
| --- | --- |
| `]h` / `[h` | next / previous git hunk |
| `<leader>gs`, `<leader>gr`, `<leader>gS` | stage / reset hunk / stage buffer |
| `<leader>gp`, `<leader>gb`, `<leader>gB` | preview hunk / blame line / toggle line blame |
| `<leader>gd` / `<leader>gh` | diffview / file history |
| `<leader>gg` | lazygit |

#### Debug

| Key | Action |
| --- | --- |
| `<leader>Db`, `<leader>Dc`, `<leader>Di`, `<leader>Do`, `<leader>DO`, `<leader>Dr`, `<leader>Dt`, `<leader>Du` | breakpoint / continue / step into / step over / step out / REPL / terminate / DAP UI |

#### Test

| Key | Action |
| --- | --- |
| `<leader>tt`, `<leader>tf`, `<leader>td`, `<leader>ts`, `<leader>to`, `<leader>tl` | run nearest / run file / debug nearest / summary / output / run last |

#### Tasks

| Key | Action |
| --- | --- |
| `<leader>or` / `<leader>ot` | run task / task list (overseer) |

#### Data

| Key | Action |
| --- | --- |
| `<leader>dr`, `<leader>dt`, `<leader>db`, `<leader>dc`, `<leader>dD` | dbt run/test/build/compile/debug when `dbt` exists |
| `<leader>du` | database UI |

#### Panes

| Key | Action |
| --- | --- |
| `<M-h/j/k/l>` | move between splits, then tmux panes (smart-splits) |

