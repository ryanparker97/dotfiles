#!/bin/zsh -f
# Unit test for _zsh_cached_init (custom/cache.zsh): the cache is keyed on the
# resolved binary path and the arguments behind a format marker, is compiled without
# the calling shell's aliases, and is replaced without a window in
# which a half-written file exists. Touches nothing outside its own temp dir.
# Usage: zsh -f tests/cache.test.zsh   (exit 0 all pass, 1 a case failed)
# To test another copy of the helper: CACHE_ZSH=<file> zsh -f tests/cache.test.zsh

emulate -L zsh
umask 077
zmodload zsh/stat zsh/datetime

local here=${0:A:h}
local helper=${CACHE_ZSH:-${here:h}/custom/cache.zsh}
[[ -r $helper ]] || { print -u2 "cache.test: cannot read $helper; run from a checkout with custom/cache.zsh"; exit 2 }

local T
T=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cache-test.XXXXXX") || { print -u2 "cache.test: no temp dir; set TMPDIR to a writable directory"; exit 2 }
trap '/bin/rm -rf -- "$T"' EXIT INT TERM HUP

mkdir -p $T/bin $T/real $T/cache
export ZSH_CACHE_DIR=$T/cache
path=($T/bin /usr/bin /bin)
source $helper

# Two distinct fake tools; each prints one line that names itself and holds a checksum of its
# arguments (so the arguments change the output, and can never put a second line in it).
local n
for n in one two; do
  print -rl -- '#!/bin/sh' 'echo "echo ran-'$n' $(printf %s "$*" | cksum | cut -d" " -f1)"' >| $T/real/$n
  chmod 700 $T/real/$n
  /usr/bin/touch -t 201901010000 $T/real/$n   # older than any cache made below (the Homebrew case)
done
ln -s $T/real/one $T/bin/tool

local cache=$T/cache/init-tool.zsh fails=0
ok()   { print "PASS $1" }
bad()  { print "FAIL $1"; (( fails++ )) }
mt()   { zstat +mtime -- $1 }
run()  { _zsh_cached_init "$@" >/dev/null 2>&1 }

# (a) the first call creates the cache.
run tool init zsh
if [[ -s $cache ]] && /usr/bin/grep -q '^echo ran-one ' $cache; then ok "(a) first call creates the cache"
else bad "(a) first call creates the cache"; fi

# (d) no change leaves the cache's mtime alone (cache made older than now, newer than the binaries).
/usr/bin/touch -t 202001010000 $cache
local before=$(mt $cache)
run tool init zsh
if [[ $(mt $cache) == $before ]]; then ok "(d) no change leaves the cache alone"
else bad "(d) no change leaves the cache alone (mtime changed)"; fi

# (b) the symlink now resolves to another binary whose mtime is older than the cache.
ln -sf $T/real/two $T/bin/tool
run tool init zsh
if /usr/bin/grep -q '^echo ran-two ' $cache && ! /usr/bin/grep -q 'ran-one' $cache; then ok "(b) a different resolved binary regenerates"
else bad "(b) a different resolved binary regenerates (cache still holds the old tool's output)"; fi

# (c) a change of arguments regenerates.
/usr/bin/touch -t 202001010000 $cache
local old=$(<$cache)
run tool init bash
if [[ -s $cache && $(<$cache) != $old ]] && /usr/bin/grep -q '^echo ran-two ' $cache; then ok "(c) a change of arguments regenerates"
else bad "(c) a change of arguments regenerates (cache still holds the old arguments' output)"; fi

# (e) no temporary file is left beside the cache, after creating and after replacing it.
local -a stray
stray=( $T/cache/*(DN:t) )
stray=( ${stray:#init-tool.zsh} )
stray=( ${stray:#init-tool.zsh.zwc} )
if (( ${#stray} == 0 )); then ok "(e) no temporary file is left beside the cache"
else bad "(e) no temporary file is left beside the cache: ${stray[*]}"; fi

# (f) arguments holding a newline, '#', quotes and a command substitution are never evaluated
#     and cannot add a line to the cache: at most one line (the key) precedes the tool's own output.
local marker=$T/pwned
local evil=$'x\necho pwned >'$marker$'\n# \' " $(/usr/bin/touch '$marker$') `/usr/bin/touch '$marker$'`'
run tool $evil
run tool $evil       # the second call sources the cache again from the key it wrote
local extra=$(( $(/usr/bin/wc -l < $cache) - 1 ))   # the tool prints one line (no newline in its echo)
local first; IFS= read -r first < $cache
if [[ ! -e $marker ]] && (( extra <= 1 )) && { (( extra == 0 )) || [[ $first == '# '* ]] }; then
  ok "(f) hostile arguments are not evaluated and add no line"
else
  bad "(f) hostile arguments are not evaluated and add no line (marker: ${${:-$([[ -e $marker ]] && print present)}:-absent}, extra lines: $extra)"
fi


# (g) an alias defined while the cache is compiled is not expanded into the compiled copy:
#     zsh loads the .zwc, so it must hold the tool's own words (zcompile -U), not the alias's.
ln -s $T/real/one $T/bin/atool; rehash
local acache=$T/cache/init-atool.zsh got
alias echo='print -r -- aliased'
run atool init zsh
unalias echo
got=$(source $acache 2>/dev/null)
if [[ -s $acache.zwc && $got == 'ran-one '* ]]; then ok "(g) an alias is not compiled into the cache"
else bad "(g) an alias is not compiled into the cache (.zwc: ${${:-$([[ -s $acache.zwc ]] && print present)}:-absent}, output: $got)"; fi

# (h) a cache whose first line is the key without the format marker (written before the
#     marker existed) regenerates once, though the binary and arguments are unchanged.
ln -s $T/real/one $T/bin/otool; rehash
local ocache=$T/cache/init-otool.zsh
local -a owords=( "${${:-$T/real/one}:A}" init zsh )
print -rl -- "# zsh-cache-key: ${(j: :)${(@qqqq)owords}}" 'echo stale' >| $ocache
/usr/bin/touch -t 202001010000 $ocache
run otool init zsh
if /usr/bin/grep -q '^echo ran-one ' $ocache && ! /usr/bin/grep -q stale $ocache; then ok "(h) a cache keyed without the format marker regenerates"
else bad "(h) a cache keyed without the format marker regenerates (it still holds the old output)"; fi

print "cache.test: $helper: $(( fails == 0 ? 8 : 8 - fails )) of 8 cases pass"
(( fails == 0 ))
