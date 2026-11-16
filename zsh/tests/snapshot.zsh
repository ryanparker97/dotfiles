#!/bin/zsh -f
# Snapshot the state an interactive zsh ends up in, compare two snapshots and
# check one against tests/inventory.txt. Needs no terminal of its own: the
# interactive shell runs under a PTY from /usr/bin/script.
#
# Usage:
#   zsh tests/snapshot.zsh <out>                       write a snapshot to <out>
#   zsh tests/snapshot.zsh --diff <a> <b> [allow-ere]  print lines that differ
#   zsh tests/snapshot.zsh --inventory <snap>          check inventory.txt keys
#   zsh tests/snapshot.zsh --selftest <snap>           prove --diff and masking work
#   zsh tests/snapshot.zsh --mask                      mask stdin the same way
#
# Exit: 0 ok; 1 a difference outside the allow-regex, a missing inventory key or
# a failed self-test; 2 cannot run (bad arguments, unreadable file, no PTY, or a
# secret-shaped value that masking did not remove).
#
# Masking rule (snapshots sync off the machine): the home directory, the host
# names and the login name become $HOME, $HOSTNAME and $USER; per-shell values
# become <masked>. A host name of five characters or fewer is masked only as a
# whole token: not where the character before or after it is a letter, a digit
# or an underscore, so a short name (the hostname can follow the network) never
# rewrites a word such as `emacs`; a longer one is masked wherever it occurs. No mask touches the `kind|` prefix of a snapshot line, and
# a snapshot that lacks any of its kinds is refused (exit 2). Exported values are an allow-list: an `export` or
# `nonint-export` value is written in clear only for a name in SAFE_EXPORTS,
# and every other exported value becomes <sha:XXXXXXXX>, a hash keyed on this
# Mac's hardware UUID, so an export added, removed or changed still shows in
# --diff by name while its value never does. A `var` whose name contains TOKEN,
# SECRET, PASS, KEY, CRED, AUTH, COOKIE or SESSION (or ends in _PAT), and any
# secret-shaped text in any line, safe names included, is hashed the same way.
# With no hardware UUID there is no key, and the script writes nothing (exit 2).

emulate -R zsh
setopt extendedglob
umask 077              # every temporary file is owner-only
# Byte-order sorting, so two machines and two locales sort the same way.
export LC_ALL=C

typeset -r TESTS_DIR=${0:A:h}
typeset -r SELF=${0:A}
typeset -r INVENTORY=$TESTS_DIR/inventory.txt

# Every kind a snapshot holds, in file order. Kinds in KEEP_ORDER keep the
# order the shell has them in (hook order shows a fragment sourced on the
# wrong side of Oh My Zsh); every other kind is sorted.
typeset -ra KINDS=(
  alias function fnsrc export var path fpath
  bind-emacs bind-viins bind-vicmd keymap option zstyle plugin widget hook
  nonint-export nonint-path login-path
)
typeset -ra KEEP_ORDER=(path fpath plugin hook nonint-path login-path)
# Kinds whose inventory key is `kind|name`: any value counts.
typeset -ra NAME_KEYED=(alias function export)

# Exported names whose values are written in clear; every other exported value
# is hashed. Adding a name is the owner's call, not a unit's.
typeset -ra SAFE_EXPORTS=(
  # Paths under the home directory set by core/zshenv (tracked); the shells run
  # under env -i, so no caller value replaces the default; written as $HOME.
  XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME ZSH_CONFIG_ROOT ZSH STARSHIP_CONFIG
  # Literals in core/zshenv; the inventory names them.
  EDITOR VISUAL COLORTERM JAVA_HOME
  # Literals in custom/fzf.zsh; a changed fzf option must be readable in a diff.
  FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_DEFAULT_OPTS FZF_CTRL_T_OPTS
  # Set by this script's own env -i; the identity mask writes $HOME and $USER.
  HOME USER LOGNAME
  # Constants this script's own env -i sets.
  TERM LANG
  # The same entries the path, nonint-path and fpath kinds list one per line.
  PATH FPATH
  # A 0/1 flag the pay-respects unit sets and reads.
  _PR_AI_DISABLE
)

# Secret shapes, as POSIX extended regexes (matched with zsh's =~).
typeset -r Q="'"
typeset -r RE_TOKENS='gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{16,}|xox[abeprs]-[A-Za-z0-9-]{10,}|(AKIA|ASIA)[0-9A-Z]{16}|glpat-[A-Za-z0-9_-]{16,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(\.[A-Za-z0-9_-]+)?|-----BEGIN[A-Z ]*PRIVATE KEY-----'
typeset -r RE_HEADER='(bearer|basic)[[:space:]]+[A-Za-z0-9._~+/=-]{8,}'          # case-insensitive
typeset -r RE_URLCRED='[a-z][a-z0-9+.-]*://[^/:@[:space:]]+:[^/@[:space:]]+@'    # case-insensitive
typeset -r RE_KV="(token|secret|passw(or)?d|api[_-]?key|access[_-]?key|private[_-]?key|auth[a-z_]*|cookie|credentials?)[\"${Q}]?[[:space:]]*[=:][[:space:]]*[\"${Q}]?[^[:space:]\"${Q}<]{6,}"  # case-insensitive
typeset -r RE_LONG='[A-Za-z0-9_+-]{32,}'   # masked only with a digit, a lower- and an upper-case letter

typeset -ga _CLEAN _KIDS _HOSTS
typeset -g _LOGIN _KEY _H
integer _KEY_SET=0

_usage() {
  print -r -- "usage: zsh ${SELF:t} <out> | --diff <a> <b> [allow-ere] | --inventory <snap> | --selftest <snap> | --mask

  <out>                  dump the interactive login shell's state to <out>, one
                         'kind|text' line each, masked (see the rule at the top of this file)
  --diff A B [ERE]       print every line only in A as '< line', only in B as '> line';
                         exit 1 when a line does not match the extended regex ERE
  --inventory SNAP       exit 1 and list the keys of ${INVENTORY:t} missing from SNAP
  --selftest SNAP        exit 1 unless every kind is present, --diff reports a removed,
                         changed, added (and, for ordered kinds, moved) line of each kind,
                         and canary secrets never survive masking
  --mask                 copy stdin to stdout with the same masking (used by verify.zsh)

examples:
  zsh tests/snapshot.zsh /tmp/before.snap
  zsh tests/snapshot.zsh --diff before.snap after.snap '^[<>] alias\\|(ll|la)='"
}

_die() {  # <exit> <message> [fix]
  print -ru2 -- "snapshot: $2"
  [[ -n ${3-} ]] && print -ru2 -- "  fix: $3"
  exit $1
}

# Cleanup runs on every exit, including Ctrl-C, SIGTERM and SIGHUP: stop the
# shells still running, then delete every temporary path.
_cleanup() {
  local p
  for p in $_KIDS; do kill -TERM $p 2>/dev/null; done
  _KIDS=()
  (( $#_CLEAN )) && /bin/rm -rf -- $_CLEAN
  _CLEAN=()
}
trap _cleanup EXIT
trap '_cleanup; exit 130' INT
trap '_cleanup; exit 143' TERM
trap '_cleanup; exit 129' HUP

_tmpdir() {  # sets REPLY to a new owner-only directory that cleanup removes
  REPLY=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/zsh-snapshot.XXXXXX") || _die 2 "cannot create a temporary directory" "check that \$TMPDIR is writable"
  _CLEAN+=( $REPLY )
}

_run() {  # run a command in the background so a signal can stop it
  "$@" &
  local pid=$!
  _KIDS+=( $pid )
  wait $pid
  local rc=$?
  _KIDS=( ${_KIDS:#$pid} )
  return $rc
}

# ---------------------------------------------------------------------------
# Masking.

_identities() {  # host names and login name, longest first
  (( $#_HOSTS )) && return
  local -a h by_len
  local x
  h=( $HOST $(/bin/hostname 2>/dev/null) $(/bin/hostname -s 2>/dev/null)
      "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)"
      "$(/usr/sbin/scutil --get ComputerName 2>/dev/null)" )
  h=( ${(u)h:#?(#c0,2)} )                        # drop empty and very short names
  for x in $h; by_len+=( "${(l:4::0:)${#x}}:$x" )
  _HOSTS=( ${${(On)by_len}#*:} )                 # longest first, so a short name never splits a long one
  _LOGIN=${USER:-$(/usr/bin/id -un)}
}

# The hash key: this Mac's hardware UUID, never written anywhere. There is no
# fallback key: a hash made with a known key could be tested against guesses.
_key_from() {  # <ioreg text>; sets _KEY, or exits 2 when the text holds no UUID
  local -a l
  l=( ${(M)${(f)1}:#*IOPlatformUUID*} )
  _KEY=${${l[1]##*= \"}%%\"*}
  [[ -n ${l[1]-} && $_KEY == [0-9A-Fa-f-](#c8,) ]] ||
    _die 2 "cannot read this Mac's hardware UUID (IOPlatformUUID) from ioreg, so there is no hash key; nothing was written" \
      "run: /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice  and check it lists IOPlatformUUID"
}

_machine_key() {
  (( _KEY_SET )) && return
  _key_from "$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null)"
  _KEY_SET=1
}

_hash() {  # <value>; sets _H to <sha:XXXXXXXX>
  _machine_key
  local h
  h=$(print -rn -- "$_KEY:$1" | /usr/bin/shasum -a 256)
  _H="<sha:${h[1,8]}>"
}

_mask_re() {  # <ere> <ignore-case 0|1> <mixed-only 0|1>; masks matches in REPLY
  local re=$1 out= rest=$REPLY m
  [[ $2 == 1 ]] && setopt localoptions nocasematch
  while [[ -n $rest && $rest =~ $re ]]; do
    m=$MATCH
    if [[ $3 == 1 ]] && ! [[ $m == *[0-9]* && $m == *[a-z]* && $m == *[A-Z]* ]]; then
      out+=${rest[1,MEND]}
    else
      _hash $m
      out+=${rest[1,MBEGIN-1]}$_H
    fi
    rest=${rest[MEND+1,-1]}
  done
  REPLY=$out$rest
}

_mask_host() {  # <name>: replace case-insensitive matches in REPLY with $HOSTNAME, whole tokens only for a name of 5 characters or fewer
  local lh=${(L)1} s=$REPLY out= before after
  integer n=${#1} p
  if (( n > 5 )); then                          # a long name is no part of an ordinary word: masked anywhere
    REPLY=${REPLY//(#i)${(b)1}/\$HOSTNAME}
    return
  fi
  while [[ -n $s ]]; do                         # an empty string gives index 0, so stop there
    p=${${(L)s}[(i)${(b)lh}]}
    (( p < 1 || p > ${#s} )) && break
    (( p > 1 )) && before=${s[p-1]} || before=
    after=${s[p+n]}
    if [[ $before == [A-Za-z0-9_] || $after == [A-Za-z0-9_] ]]; then
      out+=${s[1,p+n-1]}                         # part of a longer word: left as is
    else
      out+=${s[1,p-1]}\$HOSTNAME
    fi
    s=${s[p+n,-1]}
  done
  REPLY=$out$s
}

_mask_ids() {  # REPLY: home, host names, login name; a snapshot line's kind| prefix is kept
  local h pre=
  _identities
  if [[ $REPLY == *'|'* ]] && (( ${KINDS[(Ie)${REPLY%%|*}]} )); then
    pre=${REPLY%%|*}'|'; REPLY=${REPLY#*|}
  fi
  REPLY=${REPLY//${(b)HOME}/\$HOME}
  for h in $_HOSTS; _mask_host $h
  (( ${#_LOGIN} > 2 )) && REPLY=${REPLY//(#i)${(b)_LOGIN}/\$USER}
  REPLY=$pre$REPLY
}

_mask_secrets() {  # REPLY: the export allow-list, secret var names, secret shapes
  local kind=${REPLY%%|*} name val
  if [[ $kind == (export|nonint-export|var) && $REPLY == *=* ]]; then
    name=${${REPLY#*|}%%=*}
    val=${REPLY#*=}
    if [[ $val == '<masked>' || $val == '<sha:'[0-9a-f](#c8)'>' ]]; then
      :                                   # already masked or hashed
    elif [[ $kind == (export|nonint-export) ]]; then
      if (( ! ${SAFE_EXPORTS[(Ie)$name]} )); then
        _hash $val
        REPLY="$kind|$name=$_H"
      fi
    elif [[ $name == (#i)(*(token|secret|pass|key|cred|auth|cookie|session)*|*_pat) ]]; then
      _hash $val
      REPLY="$kind|$name=$_H"
    fi
  fi
  local pre=                              # the shape masks below never touch the kind| prefix
  if [[ $REPLY == *'|'* ]] && (( ${KINDS[(Ie)$kind]} )); then
    pre=$kind'|'; REPLY=${REPLY#*|}
  fi
  [[ $REPLY == *(gh|sk-|xox|AKIA|ASIA|glpat|eyJ|BEGIN)* ]] && _mask_re $RE_TOKENS 0 0
  [[ $REPLY == (#i)*(bearer|basic)* ]] && _mask_re $RE_HEADER 1 0
  [[ $REPLY == *://*@* ]] && _mask_re $RE_URLCRED 1 0
  [[ $kind != (export|nonint-export|var) && $REPLY == (#i)*(token|secret|pass|key|auth|cookie|cred)* ]] &&
    _mask_re $RE_KV 1 0
  [[ $REPLY == *[A-Za-z0-9_+-](#c32,)* ]] && _mask_re $RE_LONG 0 1
  REPLY=$pre$REPLY
}

_mask_lines() {  # <array name>: mask every element in place
  local -a src=( "${(@P)1}" ) dst
  for REPLY in $src; do
    _mask_ids
    _mask_secrets
    dst+=( $REPLY )
  done
  set -A $1 "${(@)dst}"
}

_leak_check() {  # <array name>: exit 2 when masking would still change a line
  local -a lines=( "${(@P)1}" )
  local i
  for (( i = 1; i <= $#lines; i++ )); do
    REPLY=$lines[i]
    _mask_secrets
    [[ $REPLY == $lines[i] ]] && continue
    _die 2 "line $i (${lines[i]%%|*}) still holds a secret-shaped value after masking; nothing was written" \
      "report this to the script's owner; do not copy the line anywhere"
  done
}

# ---------------------------------------------------------------------------
# Dump. Sourced inside the shell under test with: <out> <mode>.
# mode full = interactive login shell; nonint = `zsh -c`; login = `zsh -l -c`.
# Line 1 saves the options before line 2 turns alias expansion off, so the
# rest of the file is parsed without the config's aliases (OMZ defines `_`,
# `...` and others that would rewrite this code). Only an anonymous function
# runs, so the dump adds no function, alias, widget or export of its own.
typeset DUMP_CODE
read -r -d '' DUMP_CODE <<'EOF'
\builtin typeset -gA __snap_opt; __snap_opt=( "${(@kv)options}" )
\builtin setopt no_aliases
() {
  emulate -L zsh
  setopt extendedglob no_aliases
  zmodload zsh/parameter 2>/dev/null
  zmodload zsh/zleparameter 2>/dev/null
  local out=$1 mode=$2 k v h f map
  local -a names arr
  {
    if [[ $mode == (full|nonint) ]]; then
      [[ $mode == full ]] && h=export || h=nonint-export
      for k in ${(ok)parameters}; do
        [[ ${parameters[$k]} == *export* ]] || continue
        case $k in
          (SHLVL|PWD|OLDPWD|_|STARSHIP_SESSION_KEY|ATUIN_SESSION) v="<masked>" ;;
          (*) v=${(P)k} ;;
        esac
        print -r -- "$h|$k=${v//$'\n'/\\n}"
      done
    fi
    case $mode in
      (full)   h=path ;;
      (nonint) h=nonint-path ;;
      (login)  h=login-path ;;
    esac
    for v in $path; print -r -- "$h|$v"

    if [[ $mode == full ]]; then
      for v in ${(f)"$(alias)"}; print -r -- "alias|$v"
      for f in ${(ok)functions}; print -r -- "function|$f"
      for f in _zsh_autosuggest_start _zsh_highlight _zsh_cached_init; do
        print -r -- "fnsrc|$f=${functions_source[$f]-}"
      done
      names=(HISTFILE HISTSIZE SAVEHIST ZSH_STATE_DIR ZSH_CACHE_DIR ZSH_COMPDUMP
             ZSH_THEME ${(k)parameters[(I)ZSH_AUTOSUGGEST_*]} _FZF_PREVIEW_CMD)
      for k in $names; do
        if (( ! ${+parameters[$k]} )); then
          v="<unset>"
        elif [[ ${parameters[$k]} == association* ]]; then
          arr=( "${(@kvP)k}" ); v="(${(j: :)${(@q-)arr}})"
        elif [[ ${parameters[$k]} == array* ]]; then
          arr=( "${(@P)k}" ); v="(${(j: :)${(@q-)arr}})"
        else
          v=${(P)k}
        fi
        print -r -- "var|$k=${v//$'\n'/\\n}"
      done
      for v in $fpath; print -r -- "fpath|$v"
      for map in emacs viins vicmd; do
        for v in ${(f)"$(bindkey -M $map)"}; print -r -- "bind-$map|$v"
      done
      for v in ${(f)"$(bindkey -lL main)"}; print -r -- "keymap|$v"
      for k in ${(ok)__snap_opt}; print -r -- "option|$k=$__snap_opt[$k]"
      for v in ${(f)"$(zstyle -L)"}; print -r -- "zstyle|$v"
      for v in $plugins; print -r -- "plugin|$v"
      for k in ${(ok)widgets}; do
        [[ $widgets[$k] == builtin ]] || print -r -- "widget|$k=$widgets[$k]"
      done
      for h in precmd preexec chpwd; do
        for f in ${(P)${:-${h}_functions}}; print -r -- "hook|$h=$f"
      done
      [[ -t 0 ]] && print -r -- "#tty yes" || print -r -- "#tty no"
    fi
    print -r -- "#end $mode"
  } >| $out
} "$@"
\builtin unset __snap_opt
EOF
typeset -r DUMP_CODE

_snapshot() {  # <out>
  local out=${1:a} dir raw dumpfile user=${USER:-$(/usr/bin/id -un)}
  [[ -d ${out:h} ]] || _die 2 "cannot write ${out}: directory ${out:h} does not exist" "create it with: mkdir -p ${out:h}"
  [[ -x /usr/bin/script ]] || _die 2 "/usr/bin/script is missing; it provides the PTY the interactive shell needs"
  _tmpdir; dir=$REPLY
  dumpfile=$dir/dump.zsh
  print -r -- "$DUMP_CODE" >| $dumpfile

  # Every shell: cwd / (dotenv reads .env from the cwd) and the same minimal
  # environment, so the caller's variables never reach the snapshot.
  local -a envi=(/usr/bin/env -i HOME=$HOME USER=$user LOGNAME=$user
                 TERM=xterm-256color LANG=en_US.UTF-8 PATH=/usr/bin:/bin:/usr/sbin:/sbin)
  local runner='\builtin source "$1" "$2" "$3"'
  cd / || _die 2 "cannot cd to /"
  _run $envi /usr/bin/script -q /dev/null /bin/zsh -l -i -c $runner zsh $dumpfile $dir/full full </dev/null >/dev/null 2>&1
  _run $envi /bin/zsh -c $runner zsh $dumpfile $dir/nonint nonint </dev/null >/dev/null 2>&1
  _run $envi /bin/zsh -l -c $runner zsh $dumpfile $dir/login login </dev/null >/dev/null 2>&1

  local mode
  local -a all part
  for mode in full nonint login; do
    raw=$dir/$mode
    [[ -s $raw ]] || _die 2 "the $mode shell wrote no dump" \
      "run: env -i HOME=\$HOME PATH=/usr/bin:/bin /usr/bin/script -q /dev/null /bin/zsh -l -i -c exit </dev/null  and read its errors"
    part=( ${(f)"$(<$raw)"} )
    [[ ${part[-1]} == "#end $mode" ]] || _die 2 "the $mode shell stopped before the end of the dump"
    if [[ $mode == full ]]; then
      [[ ${part[-2]} == "#tty yes" ]] ||
        _die 2 "the main shell had no terminal; /usr/bin/script gave no PTY" \
          "run from a context where 'script -q /dev/null tty </dev/null' prints a /dev/ttys device"
      part[-2]=()
    fi
    all+=( ${part[1,-2]} )
  done
  /bin/rm -rf -- $dir/full $dir/nonint $dir/login     # raw values leave the disk at once

  _mask_lines all
  _leak_check all

  local kind
  local -a sel missing
  # A kind with no line means the dump or the masking lost it: refuse the snapshot.
  for kind in $KINDS; do
    sel=( ${(M)all:#${(b)kind}[|]*} )
    (( $#sel )) || missing+=( $kind )
  done
  (( $#missing )) && _die 2 "the snapshot has no line of kind ${(j:, :)missing}; nothing was written" \
    "run: zsh ${SELF:t} --selftest <an earlier snapshot>  and compare its kinds"
  _CLEAN+=( $out.tmp.$$ )
  {
    for kind in $KINDS; do
      sel=( ${(M)all:#${(b)kind}[|]*} )
      (( ${KEEP_ORDER[(Ie)$kind]} )) || sel=( ${(o)sel} )
      (( $#sel )) && print -rl -- $sel
    done
  } >| $out.tmp.$$ || _die 2 "cannot write $out.tmp.$$"
  /bin/mv -f -- $out.tmp.$$ $out || _die 2 "cannot move the snapshot into place at $out"
}

_diff() {  # <a> <b> [allow-ere]; prints differing lines, returns 0/1/2
  local a=$1 b=$2 re=${3-} l rc bad=0 err
  local -a lines
  [[ -r $a ]] || { print -ru2 -- "snapshot: cannot read $a"; return 2 }
  [[ -r $b ]] || { print -ru2 -- "snapshot: cannot read $b"; return 2 }
  if [[ -n $re ]]; then
    err=$( { [[ '' =~ $re ]] } 2>&1 )
    [[ -n $err ]] && { print -ru2 -- "snapshot: invalid extended regex: $re"; return 2 }
  fi
  lines=( ${(f)"$(/usr/bin/diff -- $a $b)"} )
  rc=$?
  (( rc > 1 )) && { print -ru2 -- "snapshot: diff failed on $a $b (exit $rc)"; return 2 }
  lines=( ${(M)lines:#[<>] *} )
  for l in $lines; do
    print -r -- $l
    [[ -n $re && $l =~ $re ]] || (( bad++ ))
  done
  if (( $#lines )); then
    if [[ -n $re ]]; then
      print -ru2 -- "snapshot: $#lines differing lines, $bad outside the allow-regex"
    else
      print -ru2 -- "snapshot: $#lines differing lines"
    fi
  fi
  (( bad == 0 ))
}

_inventory() {  # <snap>
  local snap=$1 key kind n=0
  local -a lines keys missing
  [[ -r $snap ]] || _die 2 "cannot read $snap"
  [[ -r $INVENTORY ]] || _die 2 "cannot read $INVENTORY" "restore tests/inventory.txt from git or the unit's .pre copy"
  lines=( ${(f)"$(<$snap)"} )
  keys=( ${(f)"$(<$INVENTORY)"} )
  for key in $keys; do
    key=${key%%[[:space:]]#}
    [[ -z $key || $key == '#'* ]] && continue
    (( n++ ))
    kind=${key%%|*}
    if (( ${NAME_KEYED[(Ie)$kind]} )) && [[ $kind != function ]]; then
      (( ${lines[(I)${(b)key}=*]} )) || missing+=( $key )
    else
      (( ${lines[(Ie)$key]} )) || missing+=( $key )
    fi
  done
  (( n > 0 )) || _die 2 "$INVENTORY holds no keys" "restore tests/inventory.txt from git or the unit's .pre copy"
  if (( $#missing )); then
    print -rl -- "missing: "${^missing}
    print -ru2 -- "snapshot: ${#missing} of $n inventory keys missing from $snap"
    return 1
  fi
  print -r -- "inventory: all $n keys present"
}

_rand_hex() {  # <bytes>; sets REPLY to random lower-case hex
  REPLY=${(j::)${=$(/usr/bin/od -An -tx1 -N$1 /dev/urandom)}}
}

# Canary secrets, built at run time so no secret-shaped text sits in this file.
# Sets the array CANARY_LINES and CANARY_VALUES (what must never survive).
_canaries() {
  local hex plain tok long bearer pre1=gh pre2=sk
  _rand_hex 24; hex=$REPLY
  pre1+=p_; pre2+=-
  plain=${hex[1,12]}
  tok=$pre1${hex[1,36]}
  long=Qz${hex[1,40]}K9
  bearer=${hex[13,32]}
  _identities
  CANARY_VALUES=( $plain $tok "$pre2${hex[9,32]}" $long $bearer $_LOGIN ${(U)_LOGIN} $_HOSTS
                  ${hex[25,32]} ${hex[5,44]} )
  CANARY_LINES=(
    "export|U1CANARY_TOKEN=$plain"
    "export|U1CANARY_VALUE=$tok"
    "alias|u1canary='curl -H \"Authorization: Bearer $bearer\"'"
    "zstyle|zstyle ':u1canary:*' token '$pre2${hex[9,32]}'"
    "zstyle|zstyle ':u1canary:*' style '$long'"
    "alias|u1canary2='ssh ${_LOGIN}x@${_HOSTS[1]}.example ${(U)_LOGIN}'"
    # Shapes the old name-and-shape rule let through (privacy F6): a short
    # plain value and 40 lower-case hex characters, under plain names.
    "export|U1CANARY_MODE=${hex[25,32]}"
    "nonint-export|U1CANARY_ID=${hex[5,44]}"
  )
}

_selftest() {  # <snap>
  local snap=$1 dir kind first n i out rc fail=0 v
  local -a lines copy
  [[ -r $snap ]] || _die 2 "cannot read $snap"
  _tmpdir; dir=$REPLY
  lines=( "${(@f)$(<$snap)}" )

  _st_fail() { print -r -- "selftest: FAIL $1"; fail=1 }

  # An unchanged copy must show nothing.
  print -rl -- $lines >| $dir/same
  out=$(_diff $snap $dir/same 2>/dev/null); rc=$?
  if (( rc == 0 )) && [[ -z $out ]]; then
    print -r -- "selftest: unchanged copy ok (no difference)"
  else
    _st_fail "unchanged copy: exit $rc, output: $out"
  fi

  for kind in $KINDS; do
    i=${lines[(i)${(b)kind}[|]*]}
    n=${#${(M)lines:#${(b)kind}[|]*}}
    if (( i > $#lines )); then
      _st_fail "$kind: no line of this kind in $snap"
      continue
    fi
    first=${lines[i]}

    # 1. Removed line.
    copy=( "${(@)lines[1,i-1]}" "${(@)lines[i+1,-1]}" )
    print -rl -- $copy >| $dir/removed
    out=$(_diff $snap $dir/removed 2>/dev/null); rc=$?
    (( rc == 1 )) && [[ $out == "< $first" ]] || { _st_fail "$kind: a removed line gave exit $rc, output: $out"; continue }

    # 2. Changed line.
    copy=( "${(@)lines[1,i-1]}" "$first-selftest" "${(@)lines[i+1,-1]}" )
    print -rl -- $copy >| $dir/changed
    out=$(_diff $snap $dir/changed 2>/dev/null); rc=$?
    (( rc == 1 )) && [[ $out == *"< $first"* && $out == *"> $first-selftest"* ]] ||
      { _st_fail "$kind: a changed line gave exit $rc, output: $out"; continue }

    # 3. Added line.
    copy=( "${(@)lines[1,i]}" "$kind|selftest-added" "${(@)lines[i+1,-1]}" )
    print -rl -- $copy >| $dir/added
    out=$(_diff $snap $dir/added 2>/dev/null); rc=$?
    (( rc == 1 )) && [[ $out == "> $kind|selftest-added" ]] || { _st_fail "$kind: an added line gave exit $rc, output: $out"; continue }

    # 4. The allow-regex: a matching ERE accepts the removal, another does not.
    _diff $snap $dir/removed "^< ${kind}\\|" >/dev/null 2>&1; rc=$?
    (( rc == 0 )) || { _st_fail "$kind: an allow-regex matching the removed line gave exit $rc"; continue }
    _diff $snap $dir/removed '^> ' >/dev/null 2>&1; rc=$?
    (( rc == 1 )) || { _st_fail "$kind: an allow-regex not matching the removed line gave exit $rc"; continue }

    # 5. Order: kinds that keep their order (path kinds, plugin, hook) must
    #    report a line moved from first to last place among its kind.
    if (( ${KEEP_ORDER[(Ie)$kind]} )); then
      if (( n < 2 )); then
        _st_fail "$kind: keeps order but has $n line, so a move cannot be tested"; continue
      fi
      copy=( "${(@)lines[1,i-1]}" "${(@)lines[i+1,i+n-1]}" "$first" "${(@)lines[i+n,-1]}" )
      print -rl -- $copy >| $dir/moved
      out=$(_diff $snap $dir/moved 2>/dev/null); rc=$?
      (( rc == 1 )) && [[ $out == *"$first"* ]] || { _st_fail "$kind: a moved line gave exit $rc, output: $out"; continue }
    fi
    print -r -- "selftest: $kind ok ($n lines)"
  done

  # 6. Canaries: an export named like a secret, a secret-shaped export, alias
  #    and zstyle value, the login name and the host name never survive
  #    masking, a changed canary changes the line, and masked output is stable.
  local -a canary_a canary_b CANARY_LINES CANARY_VALUES vals_a
  _canaries; canary_a=( $CANARY_LINES ); vals_a=( $CANARY_VALUES )
  _canaries; canary_b=( $CANARY_LINES )
  _mask_lines canary_a
  _mask_lines canary_b
  local cfail=0
  local -a hit
  for v in $vals_a; do
    hit=( ${(M)canary_a:#(#i)*${(b)v}*} )
    (( $#hit )) && { cfail=1; _st_fail "canary: a value survived masking (in a ${hit[1]%%|*} line)" }
  done
  for (( i = 1; i <= $#canary_a; i++ )); do
    # line 6 holds no secret, only the login and host names, so it does not change
    (( i == 6 )) && continue
    [[ ${canary_a[i]} != ${canary_b[i]} ]] || { cfail=1; _st_fail "canary: line $i (${canary_a[i]%%|*}) did not change when its secret changed" }
  done
  print -rl -- $canary_a >| $dir/canary-a
  print -rl -- $canary_b >| $dir/canary-b
  out=$(_diff $dir/canary-a $dir/canary-b 2>/dev/null); rc=$?
  (( rc == 1 )) || { cfail=1; _st_fail "canary: --diff of two canary sets gave exit $rc" }
  ( _CLEAN=(); _KIDS=(); _leak_check canary_a ) >/dev/null 2>&1 || { cfail=1; _st_fail "canary: masked lines still hold a secret shape" }
  (( cfail )) || print -r -- "selftest: canaries ok (${#canary_a} lines: secret-named export, token export, bearer alias, two zstyle values, login and host names, short and hex values under plain export names)"

  # 7. The allow-list keeps a safe name's value in clear.
  local -a safe=( "export|EDITOR=nvim" )
  _mask_lines safe
  if [[ ${safe[1]} == "export|EDITOR=nvim" ]]; then
    print -r -- "selftest: allow-list ok (export|EDITOR=nvim unchanged)"
  else
    _st_fail "allow-list: export|EDITOR=nvim came out changed"
  fi

  # 8. No key, no hash: ioreg text without a hardware UUID must exit 2.
  ( _CLEAN=(); _KIDS=(); _KEY_SET=0; _key_from '' ) >/dev/null 2>&1; rc=$?
  if (( rc == 2 )); then
    print -r -- "selftest: hash key ok (no hardware UUID: exit 2, nothing hashed)"
  else
    _st_fail "hash key: empty ioreg text gave exit $rc, not 2"
  fi

  # 9. A short host name inside a word: with a three-letter host name injected
  #    that is a substring of `emacs`, every bind-emacs, keymap and option line
  #    comes out unchanged, and a line holding the name as a whole token comes
  #    out with $HOSTNAME in its place.
  local -a short_in short_out
  local short=mac
  short_in=( ${(M)lines:#(bind-emacs|keymap|option)[|]*} )
  if (( ! ${#${(M)short_in:#*${short}*}} )); then
    _st_fail "short host name: no bind-emacs, keymap or option line holds '$short' in $snap"
  else
    short_out=( $short_in "alias|u1canary3='ssh ${(U)short[1]}${short[2,-1]} -p 22'" )
    _identities
    ( _HOSTS=( $_HOSTS $short ); _mask_lines short_out; print -rl -- $short_out ) >| $dir/short 2>/dev/null
    short_out=( "${(@f)$(<$dir/short)}" )
    if [[ "${(pj:\n:)short_out[1,-2]}" == "${(pj:\n:)short_in}" &&
          $short_out[-1] == "alias|u1canary3='ssh \$HOSTNAME -p 22'" ]]; then
      print -r -- "selftest: short host name ok ('$short' injected: ${#short_in} bind-emacs, keymap and option lines unchanged, a whole-token use masked)"
    else
      _st_fail "short host name: '$short' injected changed a bind-emacs, keymap or option line, or left a whole-token use unmasked"
    fi
  fi

  # 10. A long host name glued to letters: a name of more than five characters,
  #     invented here, is masked inside a word too, whatever its case.
  local long=longhost$RANDOM
  local -a long_out=( "alias|u1canary4='cd /srv/x${(C)long}y'" )
  _identities
  ( _HOSTS=( $long $_HOSTS ); _mask_lines long_out; print -rl -- $long_out ) >| $dir/long 2>/dev/null
  long_out=( "${(@f)$(<$dir/long)}" )
  if [[ $long_out[1] == "alias|u1canary4='cd /srv/x\$HOSTNAMEy'" ]]; then
    print -r -- "selftest: long host name ok (a ${#long}-character name glued to letters masked)"
  else
    _st_fail "long host name: a ${#long}-character name glued to letters was left unmasked"
  fi

  (( fail == 0 )) || { print -ru2 -- "snapshot: self-test failed on $snap"; return 1 }
  print -r -- "selftest: all ${#KINDS} kinds, the canaries, the allow-list and the hash key ok"
}

case ${1-} in
  (-h|--help) _usage; exit 0 ;;
  (--diff)
    (( $# == 3 || $# == 4 )) || _die 2 "--diff takes two snapshot files and an optional extended regex" "zsh ${SELF:t} --diff <a> <b> [allow-ere]"
    _diff $2 $3 ${4-}; exit $? ;;
  (--inventory)
    (( $# == 2 )) || _die 2 "--inventory takes one snapshot file" "zsh ${SELF:t} --inventory <snap>"
    _inventory $2; exit $? ;;
  (--selftest)
    (( $# == 2 )) || _die 2 "--selftest takes one snapshot file" "zsh ${SELF:t} --selftest <snap>"
    _selftest $2; exit $? ;;
  (--mask)
    (( $# == 1 )) || _die 2 "--mask reads stdin and takes no argument" "some-command 2>&1 | zsh ${SELF:t} --mask"
    while IFS= read -r REPLY || [[ -n $REPLY ]]; do
      _mask_ids; _mask_secrets; print -r -- $REPLY
    done
    exit 0 ;;
  ('') _usage >&2; exit 2 ;;
  (-*) _die 2 "unknown option: $1" "run: zsh ${SELF:t} --help" ;;
  (*)
    (( $# == 1 )) || _die 2 "a snapshot takes one output path" "zsh ${SELF:t} <out>"
    _snapshot $1; exit $? ;;
esac
