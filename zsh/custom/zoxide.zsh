# zoxide: cached init, after Oh My Zsh has run compinit.
# Single zoxide init (the OMZ zoxide plugin is intentionally not loaded).
[[ -o interactive ]] && _zsh_cached_init zoxide init zsh
