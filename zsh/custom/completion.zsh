# Completion: dump path and completion styles, set before Oh My Zsh runs compinit.
if (( ! ${+ZSH_COMPDUMP} )); then
  typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Cache slow completions (already on via Oh My Zsh), in the same directory it uses.
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"
