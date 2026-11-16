# Aliases, loaded after Oh My Zsh so they replace its defaults.
# ll and la use eza when installed (long table, human sizes by default; la adds hidden files).
if (( ${+commands[eza]} )); then
  alias ll='eza -l'
  alias la='eza -la'
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi

if (( ${+commands[bat]} )); then
  alias cat='bat --paging=never'
elif (( ${+commands[batcat]} )); then
  alias cat='batcat --paging=never'
fi

alias df='df -h'

# BSD diff rejects --color; probe the installed implementation first.
if (( ${+commands[diff]} )) && command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff='diff --color=auto'
fi

if (( ${+commands[nvim]} )); then
  alias vim='nvim'
fi

if (( ${+commands[lazygit]} )); then
  alias lg='lazygit'
fi
