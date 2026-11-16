# Completion fallback: a plain compinit when Oh My Zsh did not load.
# Fall back to a plain compinit when OMZ is absent so completion still works.
if (( ! ${+functions[compdef]} )); then
  autoload -Uz compinit && compinit -i -d "${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump}"
fi
