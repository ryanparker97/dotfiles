#!/bin/zsh -f
# The zsh config's one check, runnable with no terminal of its own: the $HOME
# links, `zsh -n` on every zsh file, a clean interactive start and the startup
# time. Interactive shells run under a PTY from /usr/bin/script, because
# without a terminal fzf's init prints a false "can't change option: zle".
# Every shell starts in / with the same minimal environment as snapshot.zsh,
# so a variable the caller exported cannot point the shells at another config.
#
# Usage:
#   zsh tests/verify.zsh          one "A<n> PASS|FAIL <detail>" line per check
#   zsh tests/verify.zsh --ms     only the startup median in ms over 20 runs
#   zsh tests/verify.zsh --selftest   test the masking of A2 output and the
#                                     timed-run check, starting no shell
#
# Checks: A0 links (~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.config/zsh load this
#         checkout); A1 zsh -n; A2 nothing on stderr from `zsh -i -c exit` and
#         `zsh -l -i -c exit`; A5 ten-run median of `zsh -i -c exit` <= 0.14 s;
#         A6 zshrc is a manifest of `source` lines, and every custom/*.zsh
#         opens with a '# ' purpose comment.
# Exit: 0 all pass; 1 a check failed; 2 cannot run (names the missing piece).

emulate -R zsh
setopt extendedglob
umask 077              # every temporary file is owner-only
zmodload zsh/datetime zsh/mathfunc

typeset -r SELF=${0:A}
typeset -r Z=${0:A:h:h}          # the zsh directory of this checkout
typeset -r R=${Z:h}              # the dotfiles repository
typeset -r LIMIT_MS=140          # A5 gate: 0.14 s
integer failed=0
typeset -ga _CLEAN
typeset -r USER_NAME=${USER:-$(/usr/bin/id -un)}
# The environment every shell gets; the same list as snapshot.zsh.
typeset -ra ENVI=(/usr/bin/env -i HOME=$HOME USER=$USER_NAME LOGNAME=$USER_NAME
                  TERM=xterm-256color LANG=en_US.UTF-8 PATH=/usr/bin:/bin:/usr/sbin:/sbin)

_usage() {
  print -r -- "usage: zsh ${(D)SELF} [--ms | --selftest]

  (no option)  print one 'A<n> PASS|FAIL <detail>' line per check:
                 A0  ~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.config/zsh resolve into ${(D)Z}
                 A1  zsh -n on zshrc, core/zshenv, core/zprofile, custom/*.zsh, tests/*.zsh
                 A2  zsh -i -c exit and zsh -l -i -c exit print nothing on stderr (PTY)
                 A5  median of 10 PTY runs of zsh -i -c exit is at most 0.14 s
                 A6  zshrc holds only comments, ': \${…}' fallbacks and source lines;
                     every custom/*.zsh opens with a '# ' purpose comment
  --ms         print only the median startup in milliseconds over 20 PTY runs
  --selftest   check that A2's failure text is masked (login name, host names,
               a token canary) and that a failed timed run is refused; exit 0 or 1

exit: 0 all pass, 1 a check failed, 2 cannot run"
}

# Cleanup on every exit, Ctrl-C, SIGTERM and SIGHUP included.
_cleanup() { (( $#_CLEAN )) && /bin/rm -rf -- $_CLEAN; _CLEAN=() }
trap _cleanup EXIT
trap '_cleanup; exit 130' INT
trap '_cleanup; exit 143' TERM
trap '_cleanup; exit 129' HUP

_cannot() {  # <what> <fix>
  print -ru2 -- "verify: cannot run: $1"
  print -ru2 -- "  fix: $2"
  exit 2
}

_require() {
  local p
  for p in /bin/zsh /usr/bin/script /usr/bin/time /usr/bin/env /bin/cat /usr/bin/mktemp /bin/rm; do
    [[ -x $p ]] || _cannot "$p is missing" "this check expects macOS's $p"
  done
  [[ -r $Z/tests/snapshot.zsh ]] || _cannot "tests/snapshot.zsh is missing (it masks A2's stderr)" "restore it from git"
}

_tmpdir() {  # sets REPLY to a new owner-only directory that cleanup removes
  REPLY=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/zsh-verify.XXXXXX") || _cannot "mktemp failed" "check that \$TMPDIR is writable"
  _CLEAN+=( $REPLY )
}

# Interactive shells only ever start through this PTY form. Runs
# `/bin/zsh <args> -c exit` and leaves its stderr in $1/err, its status in
# $1/status; the status file only proves that a shell started.
_pty_start() {  # <dir> <zsh option>...
  local dir=$1; shift
  $ENVI /usr/bin/script -q /dev/null /bin/zsh -c "/bin/zsh $* -c exit 2>'$dir/err'; print -r -- \$? >'$dir/status'" \
    </dev/null >/dev/null 2>&1
  [[ -s $dir/status ]] || _cannot "/usr/bin/script started no shell (no PTY)" \
    "run where 'script -q /dev/null tty </dev/null' prints a /dev/ttys device; stdin must be /dev/null"
}

_median_ms() {  # <ms>... ; integer ms values, prints the median with one decimal
  local -a v=( ${(on)@} )
  local n=$#v
  if (( n % 2 )); then
    printf '%.1f\n' $v[n/2+1]
  else
    printf '%.1f\n' $(( (v[n/2] + v[n/2+1]) / 2.0 ))
  fi
}

# A0: the links in $HOME must load this checkout, or every other check
# measures some other config. ~/.config/zsh is where core/zshenv points
# ZSH_CONFIG_ROOT in the clean environment the shells get.
_check_links() {
  local link target got bad=()
  for link target in .zshrc zshrc .zshenv core/zshenv .zprofile core/zprofile .config/zsh .; do
    got=${HOME}/$link
    target=${${:-$Z/$target}:a}
    if [[ ! -e $got ]]; then
      bad+=( "~/$link is missing" )
    elif [[ ${got:A} != $target ]]; then
      bad+=( "~/$link resolves to ${(D)${got:A}}, not ${(D)target}" )
    fi
  done
  if (( $#bad )); then
    print -r -- "A0 FAIL ${(j:; :)bad}; run ${(D)R}/install.sh to link this checkout"
    return 1
  fi
  print -r -- "A0 PASS ~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.config/zsh resolve into ${(D)Z}"
}

# A6 (e): zshrc is a manifest. Every line is a comment, a blank line, a
# `: ${...}` fallback or `source "$ZSH_CONFIG_ROOT/custom/<name>.zsh"`;
# settings belong in a fragment. The names it sources must be exactly the
# files in custom/*.zsh, each sourced once: a dropped, a doubled or an
# unsourced fragment fails, whatever the line count.
_check_manifest() {
  local i name f
  local -a lines bad sourced missing doubled stray
  local -A seen
  lines=( "${(@f)$(<$Z/zshrc)}" )
  for (( i = 1; i <= $#lines; i++ )); do
    case ${lines[i]} in
      ([[:space:]]#|[[:space:]]#\#*|': ${'*) ;;
      ('source "$ZSH_CONFIG_ROOT/custom/'[A-Za-z0-9_-]##'.zsh"')
        name=${${lines[i]#*/custom/}%.zsh\"}
        sourced+=( $name )
        (( seen[$name]++ )) ;;
      (*) bad+=( $i ) ;;
    esac
  done
  for f in $Z/custom/*.zsh(N); do
    (( ${+seen[${f:t:r}]} )) || missing+=( custom/${f:t} )
  done
  for name in ${(ok)seen}; do
    (( seen[$name] > 1 )) && doubled+=( "custom/$name.zsh (${seen[$name]} times)" )
    [[ -f $Z/custom/$name.zsh ]] || stray+=( custom/$name.zsh )
  done
  if (( $#bad )); then
    print -r -- "A6 FAIL zshrc is not only a manifest: line ${(j:, :)bad} is not a comment, a ': \${…}' fallback or a source of custom/<name>.zsh"
  fi
  (( $#missing )) && print -r -- "A6 FAIL zshrc does not source ${(j:, :)missing}: every custom/*.zsh needs one source line"
  (( $#doubled )) && print -r -- "A6 FAIL zshrc sources ${(j:, :)doubled}: each fragment once"
  (( $#stray ))   && print -r -- "A6 FAIL zshrc sources ${(j:, :)stray}, which does not exist"
  (( $#bad + $#missing + $#doubled + $#stray )) && return 1
  print -r -- "A6 PASS zshrc is a manifest: ${#sourced} source lines, one per custom/*.zsh file, comments and fallbacks only"
}

# A6 (g): no setting is defined in two files among zshrc, core/zshenv,
# core/zprofile and custom/*.zsh. A setting is an alias name, a bindkey key
# (per keymap), a setopt/unsetopt option, a zstyle pattern and style, a
# `typeset -U` line, or a variable assigned or exported at file level
# (assignments inside function bodies are local work, not settings).
# Each exception is one variable name with its reason:
typeset -rA DUP_OK=(
  XDG_CACHE_HOME  "fallback in zshrc for a shell where core/zshenv did not run"
  XDG_STATE_HOME  "fallback in zshrc for a shell where core/zshenv did not run"
  ZSH_CONFIG_ROOT "fallback in zshrc for a shell where core/zshenv did not run"
  ZSH             "fallback in zshrc for a shell where core/zshenv did not run"
  path            "assembled in core/zshenv for every shell, then extended in core/zprofile for login shells"
)

_settings_of() {  # <file>; prints one setting key per line
  local line tok cmd map opt
  local -a w rest
  integer depth=0 fn=0
  for line in "${(@f)$(<$1)}"; do
    # Skip function bodies: from `name() {` to its closing brace.
    if (( ! fn )) && [[ $line == [[:space:]]#[A-Za-z0-9_:-]##[[:space:]]#'()'[[:space:]]#'{'* ]]; then
      fn=1; depth=0
    fi
    if (( fn )); then
      (( depth += ${#line//[^\{]/} - ${#line//[^\}]/} ))
      (( depth <= 0 )) && fn=0
      continue
    fi
    [[ $line == [[:space:]]#(\#*|) ]] && continue
    w=( ${(z)line} )
    while (( $#w )); do
      # one simple command: up to ; && || | or a shell keyword
      rest=()
      while (( $#w )) && [[ ${w[1]} != (\;|\&\&|\|\||\||then|do|else|elif|fi|done|\{|\}|if|while|for|\[\[|\(\() ]]; do
        rest+=( ${w[1]} ); w[1]=()
      done
      (( $#w )) && w[1]=()
      (( $#rest )) || continue
      cmd=${rest[1]}
      case $cmd in
        (alias)
          for tok in ${rest[2,-1]}; do
            [[ $tok == -* ]] && continue
            [[ ${(Q)tok} == (#b)([^=]##)=* ]] && print -r -- "alias ${match[1]}"
          done ;;
        (bindkey)
          map=main; rest[1]=()
          while [[ ${rest[1]-} == -* ]]; do
            if [[ ${rest[1]} == -M ]]; then map=${(Q)rest[2]}; rest[1,2]=(); else rest=(); fi
          done
          while (( $#rest >= 2 )); do print -r -- "bindkey $map ${(Q)rest[1]}"; rest[1,2]=(); done ;;
        (setopt|unsetopt)
          for opt in ${rest[2,-1]}; do
            opt=${${(L)opt}//_/}; opt=${opt#no}
            print -r -- "setopt $opt"
          done ;;
        (zstyle)
          [[ ${rest[2]-} == -* ]] || (( $#rest < 3 )) || print -r -- "zstyle ${(Q)rest[2]} ${(Q)rest[3]}" ;;
        (typeset|declare|export|local)
          [[ $cmd == local ]] && continue
          rest[1]=()
          if [[ $cmd != export && -n ${(M)rest:#-*U*} ]]; then
            print -r -- "typeset -U ${(j: :)${(@)rest:#-*}}"
            continue
          fi
          for tok in ${rest:#[-+]*}; do
            [[ $tok == (#b)([A-Za-z_][A-Za-z0-9_]#)(=*|) ]] && print -r -- "var ${match[1]}"
          done ;;
        (:)
          for tok in ${rest[2,-1]}; do
            [[ $tok == (#b)'${'([A-Za-z_][A-Za-z0-9_]#)(:|)=* ]] && print -r -- "var ${match[1]}"
          done ;;
        (*)
          [[ $cmd == (#b)([A-Za-z_][A-Za-z0-9_]#)(\+|)=* ]] && print -r -- "var ${match[1]}" ;;
      esac
    done
  done
}

_check_duplicates() {
  local f key
  local -a files keys dups
  local -A where
  files=( $Z/zshrc $Z/core/zshenv $Z/core/zprofile $Z/custom/*.zsh(N) )
  for f in $files; do
    keys=( ${(u)${(f)"$(_settings_of $f)"}} )
    for key in $keys; do
      where[$key]+="${where[$key]:+, }${f#$Z/}"
    done
  done
  for key in ${(ok)where}; do
    [[ ${where[$key]} == *,* ]] || continue
    [[ $key == var\ * && -n ${DUP_OK[${key#var }]-} ]] && continue
    dups+=( "$key (${where[$key]})" )
  done
  if (( $#dups )); then
    print -r -- "A6 FAIL ${#dups} setting(s) defined in two files:"
    print -rl -- "    "${^dups}
    return 1
  fi
  print -r -- "A6 PASS no setting is defined in two files (${#where} settings in ${#files} files; ${#DUP_OK} listed exceptions)"
}

# A6 (f): every fragment opens with a one-line '# ' comment saying its purpose.
_check_purpose() {
  local f first
  local -a files bad
  files=( $Z/custom/*.zsh(N) )
  for f in $files; do
    first=
    IFS= read -r first <$f
    [[ $first == '# '?* ]] || bad+=( custom/${f:t} )
  done
  if (( $#bad )); then
    print -r -- "A6 FAIL first line is not a '# ' purpose comment: ${(j:, :)bad}"
    return 1
  fi
  print -r -- "A6 PASS every custom/*.zsh (${#files} files) opens with a '# ' purpose comment"
}

# A1: every zsh file, by glob, so new fragments are covered without editing this.
_check_syntax() {
  local f out
  local -a files bad err
  files=( $Z/zshrc $Z/core/zshenv $Z/core/zprofile $Z/custom/*.zsh(N) $Z/tests/*.zsh(N) )
  for f in $files; do
    if [[ ! -r $f ]]; then
      bad+=( "${f#$Z/}: missing" )
    elif ! out=$(/bin/zsh -f -n -- $f 2>&1); then
      err=( "${(@f)out}" )   # first error line, with the file path made relative
      bad+=( "${f#$Z/}:${err[1]#"$f:"}" )
    fi
  done
  if (( $#bad )); then
    print -r -- "A1 FAIL zsh -n: ${#bad} of ${#files} files"
    print -rl -- "    "${^bad}
    return 1
  fi
  print -r -- "A1 PASS zsh -n: ${#files} files"
}

# Print a file indented, masked like a snapshot (home, host and login names,
# secret shapes) and only then made printable: escaping first would turn a
# non-ASCII name (this Mac's computer name has one) into M- text that the mask
# no longer recognises. Records quote this output.
_print_masked() {  # <file>
  local line
  /bin/zsh -f $Z/tests/snapshot.zsh --mask <"$1" | /bin/cat -v | while IFS= read -r line; do print -r -- "    $line"; done
}

# A timed run counts only when /usr/bin/script itself did not fail: a line
# starting "script:" means no PTY and no shell, whatever time was printed.
# The shell's own exit status stays unjudged.
_sample_ok() {  # <output of one timed run>
  local -a bad
  bad=( ${(M)${(f)1}:#[[:cntrl:]]#script:*} )
  (( $#bad == 0 ))
}

# A2: a fresh interactive shell, and a login one, start and exit with nothing
# on stderr; a failure prints the stderr through _print_masked.
_check_stderr() {
  local dir label st rc=0 line
  local -a opts
  for label in '-i' '-l -i'; do
    opts=( ${=label} )
    _tmpdir; dir=$REPLY
    _pty_start $dir $opts
    st=$(<$dir/status)
    if [[ -s $dir/err ]]; then
      print -r -- "A2 FAIL PTY zsh $label -c exit wrote $(/usr/bin/wc -c <$dir/err | /usr/bin/tr -d ' ') bytes to stderr (exit $st):"
      _print_masked $dir/err
      rc=1
    else
      print -r -- "A2 PASS PTY zsh $label -c exit: stderr empty, exit $st"
    fi
    /bin/rm -rf -- $dir
  done
  return $rc
}

# A5: ten PTY runs timed by /usr/bin/time -p; its "real" line arrives after
# script's own ^D^H^H. The shell's exit status is not judged here: it is the
# status of the last command in zshrc, and A2 already proved a shell starts.
_check_time() {
  local out i
  local -a ms shown
  for i in {1..10}; do
    out=$($ENVI /usr/bin/time -p /usr/bin/script -q /dev/null /bin/zsh -i -c exit </dev/null 2>&1)
    _sample_ok "$out" ||
      _cannot "/usr/bin/script failed during timed run $i of 10, so the time is not a shell start" \
        "run: /usr/bin/script -q /dev/null /bin/zsh -i -c exit </dev/null  and read its error"
    [[ $out =~ 'real[[:space:]]+([0-9]+\.[0-9]+)' ]] ||
      _cannot "no 'real' line in /usr/bin/time -p output" "check that /usr/bin/time is the BSD time"
    shown+=( $match[1] )
    ms+=( $(( int(rint(match[1] * 1000)) )) )
  done
  local med=$(_median_ms $ms)
  local med_s=$(printf '%.3f' $(( med / 1000.0 )))
  if (( med > LIMIT_MS )); then
    print -r -- "A5 FAIL startup median ${med_s} s over 10 runs, above 0.14 s: ${shown}"
    return 1
  fi
  print -r -- "A5 PASS startup median ${med_s} s over 10 runs (limit 0.14 s): ${shown}"
}

_ms_only() {
  local i t0 t1 out
  local -a ms
  _tmpdir
  _pty_start $REPLY -i            # proves a PTY shell starts before timing any
  for i in {1..20}; do
    t0=$EPOCHREALTIME
    out=$($ENVI /usr/bin/script -q /dev/null /bin/zsh -i -c exit </dev/null 2>&1)
    t1=$EPOCHREALTIME
    _sample_ok "$out" ||
      _cannot "/usr/bin/script failed during timed run $i of 20, so the time is not a shell start" \
        "run: /usr/bin/script -q /dev/null /bin/zsh -i -c exit </dev/null  and read its error"
    ms+=( $(( int(rint((t1 - t0) * 1000)) )) )
  done
  _median_ms $ms
}

# --selftest starts no shell under test. It feeds _print_masked a line built
# at run time from the login name, every host-name form and a token-shaped
# canary, and _sample_ok a good and a refused timed-run output. It names the
# kind that failed, never a value.
_selftest() {
  local dir hex tok pre=gh out esc i good bad fail=0
  local -a vals kinds
  _tmpdir; dir=$REPLY
  hex=${(j::)${=$(/usr/bin/od -An -tx1 -N20 /dev/urandom)}}
  pre+=p_; tok=$pre${hex[1,36]}
  vals=( $USER_NAME $HOST $(/bin/hostname) $(/bin/hostname -s)
         "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)"
         "$(/usr/sbin/scutil --get ComputerName 2>/dev/null)" $tok )
  kinds=( 'login name' 'host name ($HOST)' 'host name (hostname)' 'host name (hostname -s)'
          'host name (LocalHostName)' 'computer name (ComputerName)' 'token canary' )
  print -r -- "A2 stderr canary: ${(j: / :)vals}" >| $dir/err
  out=$(_print_masked $dir/err)
  for (( i = 1; i <= $#vals; i++ )); do
    [[ -n ${vals[i]} ]] || continue
    esc=$(print -rn -- ${vals[i]} | /bin/cat -v)
    if [[ ${(L)out} == *${(L)vals[i]}* || ${(L)out} == *${(L)esc}* ]]; then
      print -r -- "selftest: FAIL mask: the ${kinds[i]} survived _print_masked"; fail=1
    fi
  done
  (( fail )) || print -r -- "selftest: mask ok (login name, five host-name forms, token canary)"

  good=$'^D^H^H\nreal 0.08\nuser 0.03\nsys 0.02'
  bad=$'script: openpty: Operation not permitted\nreal 0.00\nuser 0.00\nsys 0.00'
  if _sample_ok "$good" && ! _sample_ok "$bad"; then
    print -r -- "selftest: sample ok (a real run accepted, a script: failure refused)"
  else
    print -r -- "selftest: FAIL sample: _sample_ok accepted a script: failure or refused a real run"; fail=1
  fi
  return $fail
}

case ${1-} in
  (-h|--help) _usage; exit 0 ;;
  (--ms) (( $# == 1 )) || { _usage >&2; exit 2 }
         _require; cd / || _cannot "cd / failed" "check the filesystem"
         _ms_only; exit 0 ;;
  (--selftest) (( $# == 1 )) || { _usage >&2; exit 2 }
         _require; _selftest; exit $? ;;
  ('') ;;
  (*) print -ru2 -- "verify: unknown argument: $1"; _usage >&2; exit 2 ;;
esac

_require
# Shells start in /: the dotenv plugin sources .env from the cwd.
cd / || _cannot "cd / failed" "check the filesystem"

if _check_links; then
  _check_syntax   || failed=1
  _check_manifest || failed=1
  _check_purpose  || failed=1
  _check_duplicates || failed=1
  _check_stderr   || failed=1
  _check_time     || failed=1
else
  failed=1
  _check_syntax   || :
  _check_manifest || :
  _check_purpose  || :
  _check_duplicates || :
  print -r -- "A2 FAIL not run: the links in ~ do not load this checkout"
  print -r -- "A5 FAIL not run: the links in ~ do not load this checkout"
fi
exit $failed
