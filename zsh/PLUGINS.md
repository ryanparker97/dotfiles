# Oh My Zsh plugins

`custom/omz.zsh` declares one static list of plugins and then sources Oh My Zsh. Startup does not discover, filter, install or update plugins.

## Loaded plugins

```text
dotenv fzf-tab zsh-autosuggestions zsh-syntax-highlighting
```

The order is deliberate, and the rule is written in a comment in `custom/omz.zsh`: `fzf-tab` loads after `compinit` (Oh My Zsh runs it before it sources plugins) and before the plugins that wrap widgets, and `zsh-syntax-highlighting` stays last so it wraps the widgets the earlier plugins install.

## Where each plugin comes from

| Plugin | Source | What it does |
| --- | --- | --- |
| `dotenv` | Bundled with Oh My Zsh (`~/.oh-my-zsh/plugins/dotenv`). | When you `cd` into a project directory with a `.env` file, asks once per directory (yes / no / always / never) whether to load its variables, and remembers the answer in the cache directory. |
| `fzf-tab` | A clone pinned at tag `v1.3.0` of [Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) in `~/.oh-my-zsh/custom/plugins/fzf-tab`. | Replaces Tab's completion menu with an fzf list. See [`README.md`](./README.md#keys). |
| `zsh-autosuggestions` | Bundled with Oh My Zsh. | Grey suggestions as you type. `custom/omz.zsh` sets the sources to `history completion`; atuin's init, which `custom/atuin.zsh` sources, puts atuin first when atuin is installed. |
| `zsh-syntax-highlighting` | Bundled with Oh My Zsh. | Colours the command line as you type. |

The framework itself is not a plugin and is not loaded from a clone in this repository: it lives at `~/.oh-my-zsh` (or the path in `ZSH`).

Oh My Zsh's fzf plugin is not in the list: fzf's own init is loaded directly from `custom/fzf.zsh`.

## Install fzf-tab

Run this once after installing Oh My Zsh (the install command is in [`README.md`](./README.md#install)):

```sh
git clone --depth 1 --branch v1.3.0 https://github.com/Aloxaf/fzf-tab \
  "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/fzf-tab"
```

## Update

Automatic Oh My Zsh updates are disabled (`zstyle ':omz:update' mode disabled`), so nothing updates at startup. To update Oh My Zsh and the bundled plugins, run:

```sh
git -C "${ZSH:-$HOME/.oh-my-zsh}" pull --ff-only
```

`fzf-tab` is pinned and does not change with that command. To move it, fetch and check out a newer tag in its clone yourself, then run `zsh zsh/tests/verify.zsh`.
