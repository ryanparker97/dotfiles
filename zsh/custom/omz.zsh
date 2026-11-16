# Oh My Zsh: update mode, plugin settings and list, theme, then the framework itself.
zstyle ':omz:update' mode disabled

# Order rule: fzf-tab after compinit (oh-my-zsh.sh runs it before sourcing plugins)
# and before the widget-wrapping plugins; zsh-syntax-highlighting must stay last
# so it wraps widgets from earlier plugins.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=200
plugins=(
  dotenv
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
)

ZSH_THEME=''

if [[ -r $ZSH/oh-my-zsh.sh ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 "zshrc: oh-my-zsh not found at $ZSH; install: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended"
fi
