# atuin (https://github.com/atuinsh/atuin): Ctrl-R searches history kept in atuin's local SQLite store.
# Defined only when atuin is installed. --disable-up-arrow keeps the up arrow on
# zsh's up-line-or-beginning-search, so atuin binds only ^R (emacs, viins) and /
# (vicmd). --disable-ai leaves out the `?` key, which would open atuin's AI
# assistant. The init also puts atuin first in ZSH_AUTOSUGGEST_STRATEGY (kept by
# choice); to take suggestions from zsh history again, add after the init line
#   shift ZSH_AUTOSUGGEST_STRATEGY
# which drops that first entry and leaves (history completion) as omz.zsh sets it.
# Sync and the update check are off in ~/.config/atuin/config.toml.
if (( ${+commands[atuin]} )); then
  _zsh_cached_init atuin init zsh --disable-up-arrow --disable-ai
fi
