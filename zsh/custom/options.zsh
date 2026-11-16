# General shell options.
setopt AUTOCD NOBEEP NUMERIC_GLOB_SORT

# Allow `# comment` on an interactive command line (already on via Oh My Zsh).
setopt INTERACTIVE_COMMENTS

# Temp files under the private per-user $TMPDIR (mode 700 on macOS), not the
# shared /tmp: TMPPREFIX places zsh's own (=(...), here-documents) and
# fzf-tab's per-Tab working files, which hold the words being completed.
# Only when $TMPDIR is a directory this user owns; otherwise /tmp/zsh stays.
if [[ -d $TMPDIR && -O $TMPDIR ]]; then TMPPREFIX=${TMPDIR%/}/zsh; fi
