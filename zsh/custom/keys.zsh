# Key bindings: emacs keymap, Home/End, the fzf keys, last word and edit-command-line.
# Compatibility with Alacritty, tmux and fzf. Sourced after OMZ.

# Alacritty sends ^A/^E/^U/^L and ESC b/f for Cmd/Alt shortcuts: stay on emacs keys.
bindkey -e

# tmux owns ^A as its prefix, so Cmd+Left cannot reach the line start there.
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line
bindkey '^[[F' end-of-line '^[OF' end-of-line

# tmux consumes M-c (fzf cd) and M-. (insert-last-word); offer prefix-free keys.
if (( ${+widgets[fzf-cd-widget]} )); then
  bindkey '^G' fzf-cd-widget
fi
bindkey '^[,' insert-last-word

# Ctrl-X Ctrl-E edits the command line in $EDITOR (already bound via Oh My Zsh).
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M emacs '^X^E' edit-command-line

# OMZ and fzf may install bindings after the custom widget is registered.
if [[ -o interactive ]]; then
  bindkey '^F' _fzf_file_no_hidden
fi
