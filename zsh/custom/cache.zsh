# Cache `<tool> <init args>` output and source it. The cache regenerates when it is
# missing or empty, when the binary is newer than it, or when its first line (a
# comment holding a format marker, the resolved binary path and the arguments)
# no longer matches: an upgrade that moves the symlink to a new keg must reach the
# shell even though Homebrew binaries keep their build date. Needed for GHSA-7rj6-7pqx-v7rm: the
# fzf script this caches is the one with the predictable-FIFO flaw, fixed in 0.74.5.
# Usage: _zsh_cached_init <tool> [args...]
_zsh_cached_init() {
  local tool=$1 bin=$commands[$1] cache key line tmp out
  [[ -n $bin ]] || return 1
  cache="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/init-${tool}.zsh"
  # The key is data, never code: ${(qqqq)} writes each word as $'...' with newline,
  # quote and backslash escaped, so it stays one comment line, and it is only ever
  # compared to the first line read back, not evaluated. The format marker (v2)
  # changes whenever the way a cache is built changes, so every cache built the
  # old way regenerates once (v2: compiled with -U).
  local -a words=("${bin:A}" "${(@)@[2,-1]}")
  key="# zsh-cache-key: v2 ${(j: :)${(@qqqq)words}}"
  line=
  [[ -s $cache ]] && IFS= read -r line < $cache
  if [[ $line != $key || $bin -nt $cache ]]; then
    tmp=$cache.$$
    out=$(command "$@" 2>/dev/null) || return 1
    # Write beside the cache and move into place: a shell starting now sources
    # either the old complete file or the new complete one, never a partial one.
    { print -r -- "$key"; print -r -- "$out" } >| $tmp || { command rm -f -- $tmp; return 1 }
    command mv -f -- $tmp $cache || { command rm -f -- $tmp; return 1 }
    # zsh loads the .zwc; -U keeps this shell's aliases out of it, so it runs the
    # tool's own words (without it, alias cat='bat ...' was compiled into atuin's).
    zcompile -U "$cache" 2>/dev/null
  fi
  source "$cache"
}
