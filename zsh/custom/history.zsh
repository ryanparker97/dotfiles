# History: file, size and history options.
HISTFILE="$ZSH_STATE_DIR/history"
HISTSIZE=100000
SAVEHIST=100000

# EXTENDED_HISTORY stores a start time and duration with each entry (already on via Oh My Zsh).
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY
