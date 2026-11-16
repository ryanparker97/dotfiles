# Interactive state and cache directories (ZSH_STATE_DIR, ZSH_CACHE_DIR), created owner-only.
typeset -g ZSH_STATE_DIR="$XDG_STATE_HOME/zsh"
typeset -g ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"
if [[ ! -d $ZSH_STATE_DIR || ! -d $ZSH_CACHE_DIR ]]; then
  command mkdir -p "$ZSH_STATE_DIR" "$ZSH_CACHE_DIR"
  command chmod 700 "$ZSH_STATE_DIR" "$ZSH_CACHE_DIR"
fi
