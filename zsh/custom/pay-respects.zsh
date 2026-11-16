# pay-respects (https://github.com/iffse/pay-respects, mirror of codeberg.org/iff/pay-respects): fuck/fk suggest a fix for the last command.
# Defined only when pay-respects is installed. The AI fallback module is turned
# off before the init, and --nocnf leaves out the command_not_found_handler.
if (( ${+commands[pay-respects]} )); then
  export _PR_AI_DISABLE=1
  _zsh_cached_init pay-respects zsh --alias fuck --nocnf
  # The init runs `bindkey '^X^X' __pr_inline` without -M, so it binds whatever
  # keymap is main now. With EDITOR=nvim that is viins (keys.zsh selects emacs
  # later), a keymap not typed in; with an inherited EDITOR without "vi" it is
  # emacs. Undo it in both, so no binding changes: remove it from viins and put
  # emacs's default back. The __pr_inline widget stays defined. To use the inline
  # fix, change the widget on the `bindkey -M emacs '^X^X'` line below from
  # exchange-point-and-mark to __pr_inline. Do not bind '^X^X' again in keys.zsh:
  # verify.zsh then fails, as the same key would be set in two files.
  bindkey -M viins -r '^X^X'
  bindkey -M emacs '^X^X' exchange-point-and-mark
  alias fk=fuck
fi
