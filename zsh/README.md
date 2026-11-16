# Zsh configuration

An [Oh My Zsh](https://ohmyz.sh/) configuration split into one-purpose files. `zshrc` is a short, ordered list of `source` lines; each file under `custom/` does one thing. The shell uses fzf, fzf-tab, atuin, zoxide, pay-respects and a Starship prompt. Every tool except fzf-tab is skipped cleanly when it is not installed; fzf-tab needs its clone and fzf (see [Dependencies](#dependencies)).

## Install

Do these in this order on a new machine. Nothing is installed or updated by the shell itself at startup.

1. **Install the tools** (all optional except as the [dependency table](#dependencies) says):

   ```sh
   brew install fzf zoxide starship eza bat fd atuin lazygit
   brew tap timescam/tap https://github.com/timescam/homebrew-tap
   brew install timescam/tap/pay-respects
   ```

   pay-respects is not in Homebrew core; the tap formula downloads the upstream prebuilt binary, pinned by checksum. Homebrew writes a trust entry for `timescam/tap/pay-respects` by itself (`brew untrust --formula timescam/tap/pay-respects` removes it).
2. **Write atuin's config before atuin first runs.** This file lives outside the repository and nothing else creates it. Without it atuin starts with sync and the update check on:

   ```sh
   mkdir -p ~/.config/atuin
   printf 'auto_sync = false\nupdate_check = false\n' > ~/.config/atuin/config.toml
   ```
3. **Link the startup files.** Do **not** set `ZDOTDIR`; that would make Zsh search for later startup files in another directory. From the repository root, `./install.sh` creates the links below (and the links for the other configurations in the repository), moving an existing file to `<name>.bak.<timestamp>` first. To link by hand, back up or remove existing files first:

   ```sh
   repo="$HOME/path/to/dotfiles"
   mkdir -p "$HOME/.config"
   ln -s "$repo/zsh" "$HOME/.config/zsh"
   ln -s "$repo/zsh/core/zshenv" "$HOME/.zshenv"
   ln -s "$repo/zsh/core/zprofile" "$HOME/.zprofile"
   ln -s "$repo/zsh/zshrc" "$HOME/.zshrc"
   ln -s "$repo/starship" "$HOME/.config/starship"
   ```
4. **Install Oh My Zsh** at `~/.oh-my-zsh` (or at the path you put in `ZSH`). `--keep-zshrc` leaves the `~/.zshrc` link from step 3 alone, and `--unattended` stops the installer from changing your login shell or starting zsh:

   ```sh
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
   ```
5. **Clone fzf-tab at its tag** into Oh My Zsh's custom plugins directory:

   ```sh
   git clone --depth 1 --branch v1.3.0 https://github.com/Aloxaf/fzf-tab \
     "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/fzf-tab"
   ```
6. **Open a new terminal**, then run `zsh zsh/tests/verify.zsh` from the repository root (see [Verify](#verify)).

`core/zshenv` keeps XDG variables the caller already set and otherwise uses `~/.config`, `~/.cache`, `~/.local/share` and `~/.local/state`. History lives in `~/.local/state/zsh`; completion and init caches live in `~/.cache/zsh`. `custom/state.zsh` creates both directories owner-only.

## Layout

| File | Purpose |
| --- | --- |
| `zshrc` | Interactive entry point: an ordered list of the files below. |
| `core/zshenv` | Read by every shell: XDG directories, `ZSH`, `ZSH_CONFIG_ROOT`, `STARSHIP_CONFIG`, `EDITOR`/`VISUAL` (default `nvim`), `COLORTERM`, the Homebrew and Python tool directories on `PATH`, and keg-only `openjdk` ahead of the system `java` stub with `JAVA_HOME`. The `openjdk` order holds in non-login shells (`zsh -c`, tmux panes); in a login shell macOS's `/etc/zprofile` moves it to the end of `PATH`, so `java` there is the `/usr/bin` stub. |
| `core/zprofile` | Login shells: Homebrew's `shellenv`, `~/.local/bin` first on `PATH`, OrbStack's shell integration. |
| `custom/state.zsh` | Interactive state and cache directories (`ZSH_STATE_DIR`, `ZSH_CACHE_DIR`), created owner-only. |
| `custom/history.zsh` | History: file, size and history options. |
| `custom/options.zsh` | General shell options, and `TMPPREFIX` under the private per-user temp directory. |
| `custom/completion.zsh` | Completion: dump path and completion styles, set before Oh My Zsh runs `compinit`. |
| `custom/cache.zsh` | `_zsh_cached_init`: caches a tool's init output and sources the cache. |
| `custom/pay-respects.zsh` | pay-respects: `fuck`/`fk` suggest a fix for the last command; turns its AI module off and undoes the `^X^X` bind its init makes. |
| `custom/fzf.zsh` | fzf: commands and options for its widgets, the no-hidden-files Ctrl-F widget, and fzf's own init. |
| `custom/omz.zsh` | Oh My Zsh: update mode, plugin settings and list, theme, then the framework itself. |
| `custom/aliases.zsh` | Aliases, loaded after Oh My Zsh so they replace its defaults. |
| `custom/keys.zsh` | Key bindings: emacs keymap, Home/End, the fzf keys, last word and edit-command-line. |
| `custom/compinit-fallback.zsh` | Completion fallback: a plain `compinit` when Oh My Zsh did not load. |
| `custom/zoxide.zsh` | zoxide: cached init, after Oh My Zsh has run `compinit`. |
| `custom/atuin.zsh` | atuin: Ctrl-R searches history kept in atuin's local SQLite store; its init also installs the hooks that record every command and puts atuin first among the grey suggestions. |
| `custom/prompt.zsh` | Prompt: starship's cached init, loaded last. |
| `tests/verify.zsh` | The one check: links, `zsh -n` on every file, the three rules in [Adding to the configuration](#adding-to-the-configuration), a clean interactive start, startup time. |
| `tests/snapshot.zsh` | Saves the state an interactive shell ends up in, compares two saved states, and checks one against `tests/inventory.txt`. |
| `tests/inventory.txt` | The aliases, functions, variables, options, completion styles, plugins, `PATH` entries and key bindings the configuration must keep providing. |

`tests/cache.test.zsh` is a unit test for `_zsh_cached_init`; run it from the repository root with `zsh -f zsh/tests/cache.test.zsh`.

## Load order

`zshrc` sources the files in this order. The order matters; each rule is written above its line in `zshrc`.

| # | File | Why it sits here |
| --- | --- | --- |
| 1 | `custom/state.zsh` | First: it sets `ZSH_STATE_DIR` and `ZSH_CACHE_DIR`, which later files use. |
| 2 | `custom/history.zsh` | Before Oh My Zsh: Oh My Zsh reads `HISTFILE` when it loads. |
| 3 | `custom/options.zsh` | No dependency; kept with the other early settings. |
| 4 | `custom/completion.zsh` | Before Oh My Zsh: Oh My Zsh reads `ZSH_COMPDUMP` when it runs `compinit`. |
| 5 | `custom/cache.zsh` | Before every `_zsh_cached_init` caller (pay-respects, fzf, zoxide, atuin, prompt). |
| 6 | `custom/pay-respects.zsh` | After cache: its init goes through `_zsh_cached_init`. |
| 7 | `custom/fzf.zsh` | Before Oh My Zsh: the custom widget is registered before plugin wrappers are installed. |
| 8 | `custom/omz.zsh` | Oh My Zsh itself; runs `compinit`, then loads the plugins. |
| 9 | `custom/aliases.zsh` | After Oh My Zsh: it overrides the framework's aliases. |
| 10 | `custom/keys.zsh` | After Oh My Zsh: it overrides the framework's binds, and Ctrl-G needs `fzf-cd-widget`. |
| 11 | `custom/compinit-fallback.zsh` | After keys: `compinit` binds its completion keys into the main keymap, which `keys.zsh` has just set to emacs. |
| 12 | `custom/zoxide.zsh` | After Oh My Zsh: `compinit` has to run first. |
| 13 | `custom/atuin.zsh` | After zoxide, before prompt: its Ctrl-R bind lands after Oh My Zsh's, and starship stays last. |
| 14 | `custom/prompt.zsh` | Last. |

## Dependencies

Only Oh My Zsh is required for the full setup; every other tool is optional. Install commands are in [Install](#install).

| Tool | Where it comes from | Without it |
| --- | --- | --- |
| [Oh My Zsh](https://ohmyz.sh/) | Install step 4. See [`PLUGINS.md`](./PLUGINS.md) for the plugins. | `custom/omz.zsh` prints an install hint on stderr and loads nothing from the framework: no plugins, no Oh My Zsh aliases. `custom/compinit-fallback.zsh` runs a plain `compinit`, so completion still works. |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf`. Use 0.74.5 or newer: earlier releases carry two published security advisories, one in the script `fzf --zsh` emits. | No Ctrl-T, Alt-C, Ctrl-G or fzf completion, Ctrl-F does nothing, and a Tab that would open the fzf-tab list prints a `command not found` error. |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `brew install zoxide` | Its init is skipped. |
| [Starship](https://starship.rs/) | `brew install starship`; reads `starship/starship.toml` from this repository. A Nerd Font is recommended for its symbols. | Zsh's default prompt. |
| [eza](https://github.com/eza-community/eza) | `brew install eza` | `ll` and `la` fall back to `ls -lh` and `ls -lah`. |
| [bat](https://github.com/sharkdp/bat) | `brew install bat` (the Debian name `batcat` is also found) | `cat` stays `cat`, and fzf previews use `cat`. |
| [fd](https://github.com/sharkdp/fd) | `brew install fd` | fzf file lists come from `find`. |
| [pay-respects](https://github.com/iffse/pay-respects) | Third-party tap `timescam/tap`: `brew install timescam/tap/pay-respects`. It is not in Homebrew core. | `fuck` and `fk` are not defined. |
| [atuin](https://github.com/atuinsh/atuin) | `brew install atuin`, then write `~/.config/atuin/config.toml` (Install step 2) before the first shell that has it. | Ctrl-R goes back to Oh My Zsh's incremental history search and the grey suggestions come from Zsh history. |
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | A clone pinned at tag `v1.3.0` at `$ZSH_CUSTOM/plugins/fzf-tab` (by default under `~/.oh-my-zsh`); Install step 5. | Oh My Zsh prints `plugin 'fzf-tab' not found` at startup and Tab is plain `expand-or-complete`. |
| [lazygit](https://github.com/jesseduffield/lazygit) | `brew install lazygit` | The `lg` alias is not defined. |
| Neovim (`nvim`) | Your own install. | `EDITOR` and `VISUAL` still default to `nvim` in `core/zshenv`, so set `EDITOR` yourself (Ctrl+X Ctrl+E opens it); the `vim` alias is not defined. |

Init output for fzf, zoxide, atuin, pay-respects and Starship is cached in `~/.cache/zsh/init-<tool>.zsh`. The first line of each cache is a key comment, `# zsh-cache-key: v2 ...`, holding the resolved binary path and the arguments; the cache is rebuilt when that line differs, when the binary is newer than the cache, or when the cache is missing. To force a rebuild, delete the file.

## Keys

The keys below are for the emacs keymap: `custom/keys.zsh` runs `bindkey -e`.

| Key | What it does | Set by |
| --- | --- | --- |
| `Tab` | Completes through fzf-tab: inserts a shared start or a single match at once, otherwise opens an fzf list with a description for each candidate. | `plugins` in `custom/omz.zsh` (the fzf-tab plugin) |
| `Ctrl+R` | Opens atuin's full-screen history search. | `custom/atuin.zsh` |
| `Ctrl+T` | fzf file picker with a `bat` preview. | fzf's own init, called from `custom/fzf.zsh`; the file list and preview come from the variables set there |
| `Ctrl+F` | Pick non-hidden files and append their shell-escaped paths to the line. | widget in `custom/fzf.zsh` (which also binds it in the vi insert keymap), emacs bind in `custom/keys.zsh` |
| `Ctrl+G` | fzf directory picker (`fzf-cd-widget`), for when tmux takes `Alt+C`. | `custom/keys.zsh` |
| `Alt+C` | The same fzf directory picker. | fzf's own init, called from `custom/fzf.zsh` |
| `Ctrl+X Ctrl+E` | Edit the command line in `$EDITOR`. | `custom/keys.zsh` |
| Up arrow | Walk back through history entries that start with what you typed. Atuin does not take this key. | Oh My Zsh's key bindings; `custom/atuin.zsh` passes `--disable-up-arrow` |
| `Home`, `End` | Start and end of the line (both escape-sequence forms). | `custom/keys.zsh` |
| `fuck`, `fk` | Suggest a fix for the last command; Enter runs the one you pick. `fk` is an alias for `fuck`. | `custom/pay-respects.zsh` |

Also set: `Alt+,` inserts the last word of the previous command (`custom/keys.zsh`), and `Ctrl+X .` traces one completion into a log file under `${TMPPREFIX:-/tmp/zsh}`, which is the private per-user temp directory with the setting below and `/tmp` only in a shell that has no `TMPDIR` (the fzf-tab plugin). The grey autosuggestions come from atuin first, then Zsh history, then completion; the right arrow accepts the grey suggestion (`ZSH_AUTOSUGGEST_STRATEGY`, set in `custom/omz.zsh` and put first-in-line by atuin's init, which `custom/atuin.zsh` sources).

## What to know

**`fuck` and `fk`**

- **They re-run your last command.** Outside tmux, typing either re-runs the whole last history line at once, with no prompt, to capture its error, also after a line that worked, so the parts that succeeded run again. Inside tmux they read the pane's scrollback instead, and re-run the line only when they do not find it there (a cleared pane, a line that scrolled away). Do not type them after a line with side effects (`rm`, `mv`, `git push`, `curl -X POST`, a write to a file).
- **A fix you pick runs as typed**, and one that fails again is run twice. pay-respects evaluates what it suggests; do not accept a fix for a command that holds pasted, untrusted text. The AI module is disabled (`_PR_AI_DISABLE=1`) and no command-not-found handler is installed (`--nocnf`), both in `custom/pay-respects.zsh`. To use the inline fix of the line you are typing, change the widget on the `bindkey -M emacs '^X^X'` line in that file from `exchange-point-and-mark` to `__pr_inline`; do not bind `^X^X` again in `custom/keys.zsh`, because `tests/verify.zsh` then fails (the same key would be set in two files).
- **pay-respects is not pinned.** A plain `brew upgrade` replaces the version you checked with whatever the tap then offers, unchecked, and the next new shell runs it without you typing `fuck`. To move up on purpose, in this order:
  1. `brew update`
  2. `git -C "$(brew --repository)/Library/Taps/timescam/homebrew-tap" diff dd2b015 -- Formula/pay-respects.rb`. Only the `version "..."` line and the two `sha256 "..."` lines (`on_arm` and `on_intel`) may change. Any other changed or added line, a `url` with another host or path, or a new `depends_on`, `bottle`, `post_install` or other block means do not upgrade.
  3. With `V` the version the new `version` line names, run `curl -fsSL https://api.github.com/repos/iffse/pay-respects/releases/tags/vV`. Find the asset named `pay-respects-V-aarch64-apple-darwin.tar.zst`; its `digest` must be `sha256:` followed by exactly the new `on_arm` sha256. Otherwise do not upgrade.
  4. `HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade pay-respects`, so Homebrew does not fetch the tap again and install a formula newer than the one you checked.

  `brew pin pay-respects` holds the current version (`brew unpin pay-respects` undoes it).

**atuin**

- **What it stores.** For every command run in a new shell: the command line, the directory it ran in, its exit status, its duration and time, the host name and the login name. All of it is in `~/.atuin/data/history.db`, an SQLite file that is not encrypted. Zsh keeps writing its own history file as well.
- **Leading space.** A command typed with a leading space is kept out of both atuin's store and Zsh's history file. A line that is only a comment (`# ...`) is recorded.
- **Secrets typed on a command line are stored in clear.** atuin's filter drops only lines with AWS, GitHub, Slack or Stripe key shapes. An `Authorization: Bearer <token>` header, a password given as an argument (`-p<password>`, `--password=<password>`), a token set by `export <NAME>_TOKEN=<value>`, comment lines, and mistyped or failed commands are all stored, so type such a command with a leading space. To keep commands out from now on, add `history_filter = ["<regex>"]` (matched against the command) or `cwd_filter = ["<regex>"]` (matched against the directory) to `~/.config/atuin/config.toml`. To delete what is already stored, run `atuin search --delete <query>` (it deletes every entry the query matches, so look at the matches with Ctrl-R first) or `atuin history prune` (it deletes the entries your current filters now exclude). Deleting from atuin, or deleting `~/.atuin`, does not touch Zsh's history file.
- **Each command line is briefly visible to other local accounts.** Every command line you run, leading-space and `export` lines included, is passed for a few milliseconds as a process argument to `atuin history start` before atuin decides whether to keep it, and other local accounts can see process arguments with `ps`. The text you type into Ctrl-R and the suggestion lookups go to atuin in the environment, which `ps` does not show to other accounts.
- **It shows history from every directory on a shared screen.** Ctrl-R and the grey suggestions, which appear as you type without being asked for, can show a command from any directory or session on this machine, so a short prefix can bring up a command from another project.
- **Sync is off, where the config file exists.** That is true only where `~/.config/atuin/config.toml` contains `auto_sync = false` and `update_check = false`. The file is not in this repository and `install.sh` does not create it (Install step 2); without it atuin's defaults apply, with sync and the update check on. You would know sync were on if that file lost `auto_sync = false`, if `atuin status` stopped saying `You are not logged in to a sync server`, or if a `session` file appeared in `~/.atuin/data`.

**Everything else**

- **Temp files stay in your private temp directory.** Zsh's own temp files (here-documents, here-strings, `=(...)`) and fzf-tab's per-Tab working files, which hold the words being completed, go under the private per-user `$TMPDIR` instead of the shared `/tmp`. The line that does it is in `custom/options.zsh`: `if [[ -d $TMPDIR && -O $TMPDIR ]]; then TMPPREFIX=${TMPDIR%/}/zsh; fi`. When `TMPDIR` is unset or is not a directory you own, Zsh's default `/tmp/zsh` stays. To go back to `/tmp/zsh`, delete the comment block that starts `# Temp files under the private per-user $TMPDIR` and the `if [[ -d $TMPDIR && -O $TMPDIR ]]` line from `custom/options.zsh`; `tests/verify.zsh` still passes.
- **`ll` and `la` read file names from a pipe when given no path.** That is how eza behaves, so `something | ll` is not the same as it was with `ls`. The columns are permissions, size, user, date, name; sizes are already human-readable, and `la` does not list `.` and `..`.
- **The prompt no longer shows seven modules.** `starship/starship.toml` leaves out `bun`, `deno`, `rust`, `golang`, `php`, `terraform` and `direnv`. If you install one of those tools later, the prompt does not show its version (for direnv, its state). To restore one, put its `$name\` line back into `format` (`$bun\` and `$deno\` after `$nodejs\`; `$rust\`, `$golang\`, `$php\` and `$terraform\` after `$python\`; `$direnv\` after `$kubernetes\`); it then renders in Starship's default style.
- **A newly installed `ls` or `diff` can be noticed up to a day late.** Oh My Zsh caches the result of its `ls`/`diff` colour probes in `~/.cache/zsh/appearance-probes` for a day. Deleting that file forces a fresh probe.
- **Starting a new shell is the only way to pick up a change.** Shells that are already open keep the code they loaded.

## Adding to the configuration

Where each thing goes:

| To add | Put it in | Notes |
| --- | --- | --- |
| An alias | `custom/aliases.zsh` | Wrap it in `if (( ${+commands[tool]} ))` so it is skipped when the tool is missing. |
| A key binding | `custom/keys.zsh` | Always name the keymap: `bindkey -M emacs '<key>' <widget>`. A `bindkey` with no `-M` binds whichever keymap is main at that moment, and before `keys.zsh` runs `bindkey -e` that is the vi insert keymap (`EDITOR` defaults to `nvim`). |
| An environment variable every shell needs (`PATH`, `EDITOR`, XDG directories) | `core/zshenv` | Read by every shell, including non-login and non-interactive ones. Login-only `PATH` changes go in `core/zprofile`. |
| An environment variable for one tool | That tool's file under `custom/` | For example the `FZF_*` variables are in `custom/fzf.zsh`. |
| A new tool's init | A new file under `custom/`, see below | |

To add a tool with an init script:

1. Create `custom/<tool>.zsh`. Its first line is a `# ` comment stating its one purpose.
2. Guard it on the command: `if (( ${+commands[<tool>] })); then ... fi`.
3. Call `_zsh_cached_init <tool> <init arguments>` inside the guard. For `starship init zsh` that is `_zsh_cached_init starship init zsh`.
4. Add one line to `zshrc`: `source "$ZSH_CONFIG_ROOT/custom/<tool>.zsh"`, with a comment above it that says why it sits there. It goes after `custom/cache.zsh`, after `custom/omz.zsh` if the tool needs `compdef` (completion), and before `custom/prompt.zsh`.
5. Run `zsh zsh/tests/verify.zsh`.

What `tests/verify.zsh` enforces on files, besides `zsh -n`:

- every file under `custom/` opens with a `# ` purpose comment;
- `zshrc` holds only comments, `: ${...}` fallbacks and `source` lines, and sources every file under `custom/` exactly once;
- no setting (alias, key binding in a keymap, option, `zstyle`, exported or assigned variable) is defined in two files. Five names are listed as exceptions inside `tests/verify.zsh`.

To make the configuration keep a new alias, key, variable or option, add its line to `tests/inventory.txt`; `tests/snapshot.zsh --inventory` then fails if it ever goes missing.

## Turn it off

Each procedure names lines by their text, not their number, because line numbers move as soon as one procedure has been applied. Edit the file, then open a new shell. After a procedure, `tests/verify.zsh` should still pass; a comment that mentions the removed tool may stay, and you can edit it.

**pay-respects** (`fuck`, `fk`, the AI module and the re-run behaviour):

1. In `zshrc`, delete the comment line `# pay-respects after cache: its init goes through _zsh_cached_init.` and the line `source "$ZSH_CONFIG_ROOT/custom/pay-respects.zsh"` under it. (The comment `# cache before every _zsh_cached_init caller (...)` still lists pay-respects; edit the word out if you like.)
2. Delete `custom/pay-respects.zsh`.
3. In `tests/inventory.txt`, put `# ` before the lines `alias|fk` and `alias|fuck`.

`brew uninstall pay-respects` removes the binary. `brew pin pay-respects` stops upgrades.

**atuin, the whole tool in the shell** (Ctrl-R, the recording, and the suggestions from its store):

1. In `zshrc`, delete the comment line starting `# atuin after zoxide and before prompt:` and the line `source "$ZSH_CONFIG_ROOT/custom/atuin.zsh"` under it.
2. Delete `custom/atuin.zsh`.

New shells then record nothing more into `~/.atuin`; shells already open keep recording until they exit. What the store already holds stays until you delete `~/.atuin`. No edit to `tests/inventory.txt` is needed.

**atuin, only the grey suggestions** (Ctrl-R stays on atuin): in `custom/atuin.zsh`, add this line directly after the line `_zsh_cached_init atuin init zsh --disable-up-arrow --disable-ai`, inside the `if` block:

```sh
  shift ZSH_AUTOSUGGEST_STRATEGY
```

It drops atuin from the front of the list and leaves `(history completion)`. Do not instead assign `ZSH_AUTOSUGGEST_STRATEGY=(history completion)` in that file: `tests/verify.zsh` fails because `custom/omz.zsh` already sets that name.

**fzf-tab** (Tab goes back to `expand-or-complete`): in `custom/omz.zsh`, delete the line `  fzf-tab` from the `plugins=(` list. The comment above the list still names fzf-tab; edit it if you like. For one shell only, run `disable-fzf-tab` (or `toggle-fzf-tab`). The clone can stay or be deleted.

**eza aliases** (`ll`, `la`): in `custom/aliases.zsh`, replace the comment line starting `# ll and la use eza when installed` and the block that follows it, from `if (( ${+commands[eza]} )); then` through its `fi`, with the two plain forms:

```sh
alias ll='ls -lh'
alias la='ls -lah'
```

For the current shell only, run those two lines at the prompt.

**The four refresh settings.** Oh My Zsh already turns each on, so removing them changes nothing while the framework loads; they are stated here so the settings hold without it. To remove one:

| Setting | File | Remove |
| --- | --- | --- |
| `EXTENDED_HISTORY` | `custom/history.zsh` | the comment starting `# EXTENDED_HISTORY`, and the word `EXTENDED_HISTORY` from the `setopt SHARE_HISTORY ...` line |
| `INTERACTIVE_COMMENTS` | `custom/options.zsh` | the comment starting `# Allow` and the line `setopt INTERACTIVE_COMMENTS` |
| completion caching (`use-cache`, `cache-path`) | `custom/completion.zsh` | the comment starting `# Cache slow completions` and the two `zstyle` lines with `use-cache` and `cache-path` |
| `Ctrl+X Ctrl+E` for `edit-command-line` | `custom/keys.zsh` | the comment starting `# Ctrl-X Ctrl-E` and the lines `autoload -Uz edit-command-line`, `zle -N edit-command-line` and `bindkey -M emacs '^X^E' edit-command-line` |

## Verify

From the repository root:

```sh
zsh zsh/tests/verify.zsh
```

It prints one `A<n> PASS` or `A<n> FAIL` line per check and exits 0 when all pass, 1 when a check failed, and 2 when it could not run. It runs each interactive shell under a PTY because `zsh -i -c exit` with no terminal prints a false fzf error (`can't change option: zle`). The check for startup time is load-sensitive, so run it with nothing else busy. It does not notice a missing fzf-tab clone: Oh My Zsh prints that message on stdout, which the check does not read.

`tests/snapshot.zsh` saves what an interactive shell ends up with (aliases, variables, options, key bindings, plugins), so you can take one before and one after a change and see exactly which lines differ. It needs a PTY too. `zsh zsh/tests/snapshot.zsh <file>` writes a snapshot, `--diff <before> <after>` prints the difference, and `--inventory <snapshot>` checks a snapshot against `tests/inventory.txt`. Exported values are hashed with a key taken from this Mac's hardware ID, so snapshots compare only on the machine that wrote them; exit 2 means it could not run.
