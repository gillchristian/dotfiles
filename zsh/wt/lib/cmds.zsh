# ---------------------------------------------------------------------------- #
# the worktree registry for one repo — name \t path \t branch \t locked
# (the primary and Claude Code's own worktrees are left out)
# ---------------------------------------------------------------------------- #

_wt_list() {
  git -C "$WT_ROOT" worktree list --porcelain | awk -v main="$WT_ROOT" '
    function flush() {
      if (path != "" && path != main && path !~ /\/\.claude\/worktrees\//) {
        n = split(path, seg, "/")
        printf "%s\t%s\t%s\t%s\n", seg[n], path, branch, locked
      }
      path = ""; branch = ""; locked = ""
    }
    /^worktree /  { flush(); path = substr($0, 10); next }
    /^branch /    { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
    /^detached/   { branch = "(detached)"; next }
    /^locked/     { locked = "locked"; next }
    END { flush() }
  '
}

_wt_names()   { _wt_list | cut -f1 }
_wt_path_of() { _wt_list | awk -F'\t' -v n="$1" '$1 == n { print $2 }' }

# The worktree $PWD belongs to — climbing out of a nested repo, whose own
# toplevel is not the worktree root.
_wt_wt_root_of_pwd() {
  local top d i
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  local -a paths=(${(f)"$(_wt_list | cut -f2)"})
  d=$top
  for i in 1 2 3; do
    [[ $d == $WT_ROOT ]] && { print -r -- $d; return 0 }
    [[ ${paths[(Ie)$d]} -gt 0 ]] && { print -r -- $d; return 0 }
    d=${d:h}
    [[ -z $d || $d == / ]] && break
  done
  print -r -- $top
}

_wt_current() {
  local top=$(_wt_wt_root_of_pwd)
  [[ -n $top && $top != $WT_ROOT && -n $(_wt_path_of ${top:t}) ]] && print -r -- ${top:t}
}

# ---------------------------------------------------------------------------- #
# naming
# ---------------------------------------------------------------------------- #

# How a branch name becomes a directory name. `naming` picks the strategy;
# `wt_name` in the profile overrides all of them.
#
# The case rule applies to a name a strategy actually extracted. When `ticket`
# finds no ticket it falls back to the whole branch, and that fallback is left
# alone — uppercasing `mono/item-library` into MONO-ITEM-LIBRARY helps nobody.
_wt_name_for() {
  setopt local_options extended_glob no_bash_rematch
  local branch=$1 t p matched=1
  local -a parts=(${(s:/:)branch})

  if (( $+functions[_wt_name_hook] )); then
    t=$(_wt_name_hook "$branch")
  else
    case $WT_NAMING in
      last)   t=${parts[-1]} ;;                    # feat/add-login  -> add-login
      first)  t=${parts[1]} ;;                     # feat/add-login  -> feat
      slug)   t=$branch ;;                         # feat/add-login  -> feat-add-login
      *)      # ticket: a segment that is exactly one wins, else one from anywhere
        for p in $parts; do
          [[ -n $WT_TICKET && $p =~ "^${WT_TICKET}\$" ]] && { t=$p; break }
        done
        [[ -z $t && -n $WT_TICKET && $branch =~ $WT_TICKET ]] && t=$MATCH
        [[ -z $t ]] && { t=$branch; matched=0 }
        ;;
    esac
  fi
  [[ -z $t ]] && { t=$branch; matched=0 }

  if (( matched )); then
    case $WT_NAME_CASE in
      upper) t=${t:u} ;;
      lower) t=${t:l} ;;
    esac
  fi
  _wt_slug "$t"
}

_wt_is_protected() { [[ ${WT_PROTECTED[(Ie)$1]} -gt 0 ]] }

# ---------------------------------------------------------------------------- #
# probes — the profile's own answers to "how has this diverged"
# ---------------------------------------------------------------------------- #

_wt_run_probes() {
  # extended_glob, or the [[:space:]]# repetition below is read as one space
  # followed by a literal '#' — and `wc -l` output keeps its leading spaces
  setopt local_options extended_glob
  local wtp=$1 name=$2 branch=$3 i out
  (( ${#WT_PROBE_NAME} )) || return 0
  for i in {1..${#WT_PROBE_NAME}}; do
    out=$( cd "$wtp" 2>/dev/null &&
           WT_PATH=$wtp WT_NAME=$name WT_BRANCH=$branch \
           eval "${WT_PROBE_CMD[$i]}" 2>/dev/null )
    out=${out//$'\n'/ }
    out=${out##[[:space:]]#}
    out=${out%%[[:space:]]#}
    [[ -z $out || $out == 0 ]] && continue
    print -r -- "${WT_PROBE_FMT[$i]//\{\}/$out}"
  done
}

_wt_probe_cmd() {
  local want=$1 which=${2:-$(_wt_current)} wtp i out
  wtp=${which:+$(_wt_path_of "$which")}
  [[ -z $wtp ]] && wtp=$WT_ROOT
  (( ${#WT_PROBE_NAME} )) || { _wt_info "no probes defined in $WT_REPO"; return 0 }
  for i in {1..${#WT_PROBE_NAME}}; do
    [[ -n $want && $WT_PROBE_NAME[$i] != $want ]] && continue
    print -P "%B$WT_PROBE_NAME[$i]%b  %F{8}$WT_PROBE_CMD[$i]%f"
    out=$( cd "$wtp" 2>/dev/null &&
                 WT_PATH=$wtp WT_NAME=${which:-primary} WT_BRANCH=$(_wt_head_label "$wtp") \
                 eval "${WT_PROBE_CMD[$i]}" 2>&1 )
    print -r -- "  → ${out:-(empty)}"
  done
}

# ---------------------------------------------------------------------------- #
# who is serving which port, and from where
#
# Attribution is by each listener's cwd, not by a port list: such a list goes
# stale, and the cwd is what actually ties a service to a checkout. The profile's
# `ports` only supplies labels and the "expected but down" line.
# ---------------------------------------------------------------------------- #

_wt_scan_ports() {
  WT_PORT_PID=() WT_PORT_CMD=() WT_PORT_WHERE=() WT_PORT_SEEN=() WT_RUN=()
  (( $+commands[lsof] )) || return 0

  local line pid cmd port cwd owner label
  local -a pids=() roots=() f
  local -A cwd_of all_pid all_cmd

  for line in ${(f)"$(lsof -nP -iTCP -sTCP:LISTEN -Fpcn 2>/dev/null)"}; do
    case $line in
      p[0-9]*) pid=${line#p} ;;
      c*)      cmd=${line#c} ;;
      n*)      port=${${line#n}##*:}
               [[ -n $port && -z ${port//[0-9]/} ]] || continue
               # ports the OS handed out (IANA dynamic range) are debuggers and
               # IPC, not services you start
               (( port >= 49152 )) && [[ -z ${WT_PORT_LABEL[$port]} ]] && continue
               [[ -n ${all_pid[$port]} ]] && continue          # first wins (v4/v6)
               all_pid[$port]=$pid
               all_cmd[$port]=$cmd
               pids+=$pid
               ;;
    esac
  done
  (( ${#pids} )) || return 0

  for line in ${(f)"$(lsof -a -d cwd -p ${(j:,:)${(u)pids}} -Fn 2>/dev/null)"}; do
    case $line in
      p[0-9]*) pid=${line#p} ;;
      n/*)     cwd_of[$pid]=${line#n} ;;
    esac
  done

  roots=("primary	$WT_ROOT" ${(f)"$(_wt_list)"})
  for port in ${(kon)all_pid}; do
    cwd=${cwd_of[${all_pid[$port]}]}
    owner=""
    for line in $roots; do
      f=(${(@ps:\t:)line})
      [[ -n $f[2] && ( $cwd == $f[2] || $cwd == $f[2]/* ) ]] && { owner=$f[1]; break }
    done
    # keep this repo's listeners on any port, plus known ports held by something
    # outside a checkout; ignore the rest of the machine
    [[ -z $owner ]] && { [[ -n ${WT_PORT_LABEL[$port]} ]] && owner=external || continue }

    label=${WT_PORT_LABEL[$port]:-${all_cmd[$port]}}
    # label by the subdirectory the process runs in — factual, where a port's
    # nominal name can lie
    [[ -n $WT_LABEL_DIR && $cwd == */$WT_LABEL_DIR/* ]] &&
      label=${${cwd#*/$WT_LABEL_DIR/}%%/*}

    WT_PORT_PID[$port]=${all_pid[$port]}
    WT_PORT_CMD[$port]=${all_cmd[$port]}
    WT_PORT_WHERE[$port]=$owner
    WT_PORT_SEEN[$port]=$label

    [[ $owner == external ]] && continue
    [[ " ${WT_RUN[$owner]} " == *" $label "* ]] ||
      WT_RUN[$owner]="${WT_RUN[$owner]:+${WT_RUN[$owner]} }$label"
  done
}

_wt_ports() {
  (( $+commands[lsof] )) || { _wt_die "lsof not found"; return 1 }
  _wt_scan_ports

  local port where owner
  local -a down=()

  printf "%-6s  %-12s  %-13s  %s\n" PORT SERVICE WHERE PROCESS
  for port in ${(kon)WT_PORT_PID}; do
    where=${WT_PORT_WHERE[$port]}
    printf "%-6s  %-12s  " $port "$(_wt_fit ${WT_PORT_SEEN[$port]} 12)"
    if [[ $where == external ]]; then
      printf "%-13s  " external
    else
      print -Pn "%F{14}$(printf '%-13s' $where)%f  "
    fi
    print -r -- "${WT_PORT_CMD[$port]} (${WT_PORT_PID[$port]})"
  done
  (( ${#WT_PORT_PID} )) || print -P "%F{8}nothing is listening%f"

  for port in ${(kon)WT_PORT_LABEL}; do
    [[ -n ${WT_PORT_PID[$port]} ]] || down+="$port ${WT_PORT_LABEL[$port]}"
  done
  (( ${#down} )) && print -P "%F{8}not running: ${(j:, :)down}%f"

  for owner in ${(k)WT_RUN}; do
    [[ $owner == external ]] && continue
    print -P "%F{8}served from%f %B$owner%b%F{8}: ${WT_RUN[$owner]// /, }${WT_SHARED_NOTE:+ — $WT_SHARED_NOTE}%f"
  done
}

# ---------------------------------------------------------------------------- #
# cd
# ---------------------------------------------------------------------------- #

# Jump keeping the relative subdir when the destination has it, so
# .../src/domain lands in the same place in the other worktree.
_wt_cd() {
  local dest=$1 cur rel=""
  cur=$(_wt_wt_root_of_pwd)
  [[ -n $cur && $PWD == $cur/* ]] && rel=${PWD#$cur/}
  if [[ -n $rel && -d $dest/$rel ]]; then
    cd "$dest/$rel"
  else
    cd "$dest"
  fi
  _wt_register_z "$dest"
}

_wt_pick() {
  local rows=$(_wt_list)
  (( $+commands[fzf] )) || { _wt_err "fzf not found — name the worktree"; return 1 }
  {
    printf '%s\t%s\t%s\t%s\n' primary "$WT_ROOT" "$(git -C $WT_ROOT rev-parse --abbrev-ref HEAD)" primary
    [[ -n $rows ]] && print -r -- $rows
  } | fzf --height 40% --reverse --inline-info --with-nth 1,3,4 --delimiter='\t' \
          --preview 'git -C {2} status --short --branch --untracked-files=no' |
    cut -f2
}

_wt_goto() {
  local name=$1 dest
  if [[ -z $name ]]; then
    dest=$(_wt_pick) || return 1
    [[ -z $dest ]] && return 1
  elif [[ $name == (main|primary|.) ]]; then
    dest=$WT_ROOT
  else
    dest=$(_wt_path_of "$name")
    if [[ -z $dest ]]; then
      local -a hits
      hits=(${(f)"$(_wt_list | awk -F'\t' -v n="$name" 'index($1, n) || index($3, n) { print $2 }')"})
      case ${#hits} in
        1) dest=${hits[1]} ;;
        0) _wt_die "no worktree matches $name in $WT_REPO"; return 1 ;;
        *) _wt_err "several worktrees match $name:"; print -rl -- ${hits/#/    }; return 1 ;;
      esac
    fi
  fi
  _wt_cd "$dest"
}

# ---------------------------------------------------------------------------- #
# new
# ---------------------------------------------------------------------------- #

# git worktree add, minus whatever noise the profile says to swallow
_wt_add() {
  if [[ -n $WT_ADD_FILTER ]]; then
    git -C "$WT_ROOT" worktree add "$@" 2>&1 | grep -v -E "$WT_ADD_FILTER"
    return ${pipestatus[1]}
  fi
  git -C "$WT_ROOT" worktree add "$@"
}

_wt_new() {
  local branch="" from="" as="" seed=1
  while (( $# )); do
    case $1 in
      --from) from=$2; shift 2 ;;
      --as) as=$2; shift 2 ;;
      --no-seed) seed=0; shift ;;
      -*) _wt_die "unknown flag: $1"; return 1 ;;
      *) branch=$1; shift ;;
    esac
  done
  [[ -z $branch ]] && { _wt_die "usage: wt new <branch> [--from <ref>] [--as <name>]"; return 1 }

  git -C "$WT_ROOT" fetch --quiet "$WT_REMOTE" 2>/dev/null

  # Under the ticket convention a bare ticket resolves to an EXISTING branch; it
  # cannot invent one, because only the full name carries the convention. Under
  # any other naming strategy a bare word is just a branch name, and
  # `wt new login` should make the branch `login` rather than go looking.
  setopt local_options no_bash_rematch
  if [[ $WT_NAMING == ticket && -n $WT_TICKET ]] && [[ $branch =~ "^${WT_TICKET}\$" ]]; then
    local -a hits
    hits=(${(f)"$(git -C $WT_ROOT for-each-ref --format='%(refname:short)' refs/heads refs/remotes/$WT_REMOTE |
                    sed "s|^$WT_REMOTE/||" | grep -F -i -- "$branch" | sort -u)"})
    hits=(${hits:#HEAD})
    case ${#hits} in
      0) _wt_die "no branch matches $branch — pass the full branch name"; return 1 ;;
      1) branch=${hits[1]}; _wt_info "resolved $branch" ;;
      *) _wt_err "several branches match $branch:"; print -rl -- ${hits/#/    }; return 1 ;;
    esac
  fi

  _wt_is_protected "$branch" && { _wt_die "$branch is protected — it stays in $WT_ROOT"; return 1 }

  local where
  if where=$(_wt_checked_out_in "$WT_ROOT" "$branch"); then
    if [[ $where == $WT_ROOT ]]; then
      _wt_die "$branch is checked out in the primary — use: wt adopt $branch"
    else
      _wt_die "$branch is already at $where"
    fi
    return 1
  fi

  local name=${as:+$(_wt_slug "$as")}
  [[ -z $name ]] && name=$(_wt_name_for "$branch")
  local dir=$WT_HOME/$name
  [[ -e $dir ]] &&
    { _wt_die "$dir already exists — name this one with: wt new $branch --as <name>"; return 1 }

  local base=${from:-$WT_BASE}
  if ! _wt_has_local "$WT_ROOT" "$branch" && ! _wt_has_remote "$WT_ROOT" "$WT_REMOTE/$branch"; then
    git -C "$WT_ROOT" rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
      { _wt_die "base ref $base does not exist"; return 1 }
  fi

  mkdir -p "$WT_HOME"
  _wt_head "creating %B$name%b for $branch"

  if _wt_has_local "$WT_ROOT" "$branch"; then
    _wt_add "$dir" "$branch" || { _wt_die "git worktree add failed"; return 1 }
    _wt_info "$WT_REPO: existing branch $branch"
  elif _wt_has_remote "$WT_ROOT" "$WT_REMOTE/$branch"; then
    _wt_add --track -b "$branch" "$dir" "$WT_REMOTE/$branch" || { _wt_die "git worktree add failed"; return 1 }
    _wt_info "$WT_REPO: tracking $WT_REMOTE/$branch"
  else
    # --no-track: branching off the trunk would otherwise set the new branch's
    # upstream to it, and with push.default=simple git then refuses the first
    # push and suggests `git push <remote> HEAD:<trunk>` — pushing the feature
    # branch onto the trunk. With no upstream you get the usual --set-upstream hint.
    _wt_add --no-track -b "$branch" "$dir" "$base" || { _wt_die "git worktree add failed"; return 1 }
    _wt_info "$WT_REPO: new branch $branch off $base (push with -u to publish)"
  fi

  if ! _wt_nested_attach "$dir" "$branch"; then
    _wt_err "a companion worktree failed — rolling back"
    _wt_nested_detach "$dir" 2>/dev/null
    git -C "$WT_ROOT" worktree remove --force "$dir" 2>/dev/null
    git -C "$WT_ROOT" worktree prune
    return 1
  fi

  (( seed )) && _wt_seed "$dir"
  _wt_mark_all "$dir" "$name" "$branch"
  _wt_allow_direnv "$dir"
  _wt_register_z "$dir"
  if [[ -n $WT_POST_NEW ]]; then
    _wt_info "post_new: $WT_POST_NEW"
    ( cd "$dir" && eval "$WT_POST_NEW" ) || _wt_warn "post_new failed"
  fi

  _wt_ok "$dir"
  _wt_cd "$dir"
}

_wt_mark_all() {
  local dir=$1 name=$2 branch=$3 line
  local -a f
  local label=${WT_LABEL_FORMAT:-%n}
  label=${label//\%n/$name}
  label=${label//\%p/$WT_REPO}
  _wt_mark "$dir" "$label" "$branch"
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror && -d $dir/$f[1] ]] && _wt_mark "$dir/$f[1]" "$label/$f[4]" "$branch"
  done
}

# ---------------------------------------------------------------------------- #
# adopt — move the primary's current branch into a worktree, park it on the trunk
# ---------------------------------------------------------------------------- #

_wt_adopt() {
  local branch="" as="" move=0
  while (( $# )); do
    case $1 in
      --move-changes) move=1; shift ;;
      --as) as=$2; shift 2 ;;
      -*) _wt_die "unknown flag: $1"; return 1 ;;
      *) branch=$1; shift ;;
    esac
  done
  [[ -z $branch ]] && branch=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD)
  _wt_is_protected "$branch" && { _wt_die "$branch belongs in the primary checkout"; return 1 }
  [[ $(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD) == $branch ]] ||
    { _wt_die "$branch is not checked out in the primary — use: wt new $branch"; return 1 }

  local name=${as:+$(_wt_slug "$as")}
  [[ -z $name ]] && name=$(_wt_name_for "$branch")
  local dir=$WT_HOME/$name
  [[ -e $dir ]] && { _wt_die "$dir already exists — try: wt adopt $branch --as <name>"; return 1 }

  local dirty=$(_wt_dirty_count "$WT_ROOT" $WT_DIRTY_IGNORE) stashed=0
  if (( dirty )); then
    (( move )) || { _wt_die "the primary has $dirty modified file(s) — commit them, or pass --move-changes"; return 1 }
    # stashes are repo-wide, which is exactly what carries them into the worktree
    git -C "$WT_ROOT" stash push --quiet -m "wt adopt $branch" || { _wt_die "stash failed"; return 1 }
    stashed=1
    _wt_info "stashed $dirty modified file(s)"
  fi

  # free a companion sitting on the same branch the same way
  local line moved=0
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    local src=$WT_ROOT/$f[1]
    [[ $(git -C "$src" rev-parse --abbrev-ref HEAD 2>/dev/null) == $branch ]] || continue
    (( $(_wt_dirty_count "$src" $WT_DIRTY_IGNORE) )) &&
      { _wt_die "primary $f[1] is on $branch and dirty — commit there first"; return 1 }
    local nb=$(_wt_nested_base "$src")
    git -C "$src" switch --quiet "${nb##*/}" || { _wt_die "could not park $f[1] on its trunk"; return 1 }
    moved=1
  done

  git -C "$WT_ROOT" fetch --quiet "$WT_REMOTE" 2>/dev/null
  if _wt_has_local "$WT_ROOT" "$WT_TRUNK"; then
    git -C "$WT_ROOT" switch --quiet "$WT_TRUNK" || { _wt_die "could not park the primary on $WT_TRUNK"; return 1 }
  else
    git -C "$WT_ROOT" switch --quiet -c "$WT_TRUNK" --track "$WT_BASE" ||
      { _wt_die "could not create $WT_TRUNK"; return 1 }
  fi
  git -C "$WT_ROOT" merge --ff-only "$WT_BASE" >/dev/null 2>&1
  _wt_ok "primary parked on $WT_TRUNK at $(git -C $WT_ROOT rev-parse --short HEAD)"

  mkdir -p "$WT_HOME"
  _wt_head "moving %B$branch%b into $name"
  if ! _wt_add "$dir" "$branch"; then
    _wt_err "worktree add failed; the branch is intact — retry with: wt new $branch"
    return 1
  fi
  (( moved )) && _wt_info "the companion branch comes along"
  _wt_nested_attach "$dir" "$branch" || _wt_warn "a companion worktree failed — see wt doctor"
  _wt_seed "$dir"
  _wt_mark_all "$dir" "$name" "$branch"
  _wt_allow_direnv "$dir"
  _wt_register_z "$dir"

  if (( stashed )); then
    if git -C "$dir" stash pop --quiet; then
      _wt_ok "changes restored in $name"
    else
      _wt_warn "the stash did not apply cleanly — it is still in \`git stash list\`"
    fi
  fi

  _wt_ok "$dir"
  _wt_cd "$dir"
}

# ---------------------------------------------------------------------------- #
# ls
# ---------------------------------------------------------------------------- #

_wt_ls() {
  local rows=$(_wt_list) line
  local pbranch=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD)

  local -a f state seeded
  local name wtp branch locked n pinned fmt
  local -i nw=7 bw=6
  seeded=(${(f)"$(_wt_seeded_paths)"})

  # Size the columns to the data: branch names run past any fixed width, and one
  # overflowing cell shifts every column to its right.
  (( ${#pbranch} > bw )) && bw=${#pbranch}
  for line in ${(f)rows}; do
    f=(${(@ps:\t:)line})
    (( ${#f[1]} > nw )) && nw=${#f[1]}
    (( ${#f[3]} > bw )) && bw=${#f[3]}
  done
  (( nw > 20 )) && nw=20
  (( bw > 52 )) && bw=52
  fmt="%-${nw}s  %-${bw}s  %-6s  "

  _wt_scan_ports

  print -P "%F{8}${WT_REPO} — ${WT_ROOT/#$HOME/~} (trunk $WT_TRUNK)%f"
  printf "$fmt%s\n" NAME BRANCH BEHIND STATE
  printf "$fmt" primary "$(_wt_fit "$pbranch" $bw)" "$(_wt_behind "$WT_ROOT" "$WT_BASE")"
  state=()
  [[ $pbranch == $WT_TRUNK ]] && state+="primary" ||
    state+="primary — not on $WT_TRUNK (wt adopt $pbranch)"
  [[ -n ${WT_RUN[primary]} ]] && state+="%F{14}▶${WT_RUN[primary]// /,}%f"
  print -P -- "${(j: :)state}"

  [[ -z $rows ]] && { print -P "%F{8}(no worktrees — wt new <branch>)%f"; return 0 }

  for line in ${(f)rows}; do
    f=(${(@ps:\t:)line})
    name=$f[1] wtp=$f[2] branch=$f[3] locked=$f[4]
    state=()

    [[ -n ${WT_RUN[$name]} ]] && state+="%F{14}▶${WT_RUN[$name]// /,}%f"
    n=$(_wt_dirty_count "$wtp" $WT_DIRTY_IGNORE); (( n )) && state+="%F{11}~$n%f"
    n=$(_wt_stray_untracked "$wtp" $seeded | wc -l); n=${n//[[:space:]]/}
    (( n )) && state+="%F{11}?$n%f"
    # A count of commits not in the trunk reads "unpushed" for a squash-merged
    # branch forever, so ask whether the work is actually still missing.
    n=$(_wt_unpushed "$wtp" "$branch" "$WT_BASE")
    if (( n )); then
      if _wt_contained "$wtp" "$branch" "$WT_BASE"; then
        state+="%F{10}merged%f"
      else
        state+="↑$n"
        [[ $(_wt_upstream_state "$wtp" "$branch") == gone ]] && state+="%F{11}gone%f"
      fi
    fi
    [[ -n $locked ]] && state+="%F{12}locked%f"

    pinned=$(_wt_pinned "$wtp")
    [[ -n $pinned && $pinned != $branch ]] && state+="%F{9}pinned:$pinned%f"

    [[ $branch == '(detached)' ]] && branch=$(_wt_head_label "$wtp")

    state+=(${(f)"$(_wt_nested_state "$wtp" "$branch")"})
    state+=(${(f)"$(_wt_run_probes "$wtp" "$name" "$branch")"})
    state=(${state:#})
    (( ${#state} )) || state=("%F{10}clean%f")

    print -P -- "$(printf "$fmt" "$(_wt_fit "$name" $nw)" "$(_wt_fit "$branch" $bw)" \
                          "$(_wt_behind "$wtp" "$WT_BASE")")${(j: :)state}"
  done
}

_wt_nested_state() {
  local wtp=$1 branch=$2 line nb nbranch
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    if [[ ! -d $wtp/$f[1] ]]; then
      print -r -- "%F{9}no $f[4]%f"
      continue
    fi
    nbranch=$(_wt_head_label "$wtp/$f[1]")
    nb=$(_wt_nested_base "$WT_ROOT/$f[1]")
    [[ $nbranch != $branch ]] && print -r -- "%F{11}$f[4]:$nbranch%f"
    (( $(_wt_dirty_count "$wtp/$f[1]" $WT_DIRTY_IGNORE) )) && print -r -- "%F{11}$f[4]~%f"
    (( $(_wt_unpushed "$wtp/$f[1]" "$nbranch" "$nb") )) &&
      ! _wt_contained "$wtp/$f[1]" "$nbranch" "$nb" &&
      ! _wt_work_in_base "$wtp/$f[1]" "$nbranch" "$nb" && print -r -- "$f[4]↑"
  done
}

# ---------------------------------------------------------------------------- #
# sync
# ---------------------------------------------------------------------------- #

_wt_sync() {
  local rebase=1
  [[ $1 == --no-rebase ]] && rebase=0

  _wt_head "fetching $WT_REPO"
  git -C "$WT_ROOT" fetch --prune --quiet "$WT_REMOTE" || _wt_warn "fetch failed"
  git -C "$WT_ROOT" worktree prune

  # Declared once, up front: in zsh a bare `local x` on a name that is already
  # local prints "x=value" instead of redeclaring it, so a second `local` inside
  # a loop leaks the variable to stdout.
  local line src nb nline name wtp behind nbehind rebased=0
  local pbranch ffout
  local -a f nf conflicts=() nconflicts=()

  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    git -C "$WT_ROOT/$f[1]" fetch --prune --quiet "$(_wt_detect_remote "$WT_ROOT/$f[1]")" 2>/dev/null ||
      _wt_warn "$f[1] fetch failed"
    git -C "$WT_ROOT/$f[1]" worktree prune
  done

  # primary: fast-forward the trunk, nothing cleverer
  pbranch=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD)
  if [[ $pbranch != $WT_TRUNK ]]; then
    _wt_warn "primary is on $pbranch, not $WT_TRUNK — wt adopt $pbranch"
  elif (( $(_wt_dirty_count "$WT_ROOT" $WT_DIRTY_IGNORE) )); then
    _wt_warn "primary $WT_TRUNK is dirty, not fast-forwarding"
  elif ffout=$(git -C "$WT_ROOT" merge --ff-only "$WT_BASE" 2>&1); then
    _wt_ok "primary $WT_TRUNK at $(git -C $WT_ROOT rev-parse --short HEAD)"
  else
    # Say why. The common one is an untracked file the trunk has since started
    # tracking — git refuses even when the content is byte-identical — and
    # "would not fast-forward" on its own sends you looking for the wrong thing.
    _wt_warn "primary $WT_TRUNK would not fast-forward:"
    print -rl -- ${${(f)ffout}[1,6]/#/    }
  fi
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    src=$WT_ROOT/$f[1]; nb=$(_wt_nested_base "$WT_ROOT/$f[1]")
    [[ $(_wt_head_label "$src") == ${nb##*/} ]] &&
      (( ! $(_wt_dirty_count "$src" $WT_DIRTY_IGNORE) )) &&
      git -C "$src" merge --ff-only "$nb" >/dev/null 2>&1 &&
      _wt_ok "primary $f[1] ${nb##*/} at $(git -C $src rev-parse --short HEAD)"
  done

  for line in ${(f)"$(_wt_list)"}; do
    f=(${(@ps:\t:)line})
    name=$f[1] wtp=$f[2] behind=$(_wt_behind "$wtp" "$WT_BASE")

    # A rebase already in progress is never ours to touch: `git rebase` would
    # fail and an --abort in the error path would then discard the conflict
    # resolution someone is in the middle of.
    if _wt_mid_operation "$wtp"; then
      _wt_warn "$name is mid-$(_wt_head_label "$wtp") — left alone"
    elif [[ -z $behind || $behind == 0 ]]; then
      _wt_info "$name up to date with $WT_TRUNK"
    elif (( ! rebase )); then
      _wt_info "$name is $behind behind $WT_TRUNK"
    elif (( $(_wt_dirty_count "$wtp" $WT_DIRTY_IGNORE) )); then
      _wt_warn "$name is $behind behind $WT_TRUNK but dirty — skipped"
    elif git -C "$wtp" rebase --quiet "$WT_BASE" >/dev/null 2>&1; then
      (( ++rebased ))
      _wt_ok "$name rebased onto $WT_TRUNK (+$behind)"
    else
      git -C "$wtp" rebase --abort 2>/dev/null
      conflicts+=$name
      _wt_err "$name conflicts with $WT_TRUNK — rebase it by hand"
    fi

    # A companion's trunk moves on its own schedule, so its mirror is rebased on
    # its own terms — not only when the parent branch happened to need one.
    for nline in ${(f)"$(_wt_nested_specs)"}; do
      nf=(${(@ps:\t:)nline})
      [[ $nf[2] == mirror && -d $wtp/$nf[1] ]] || continue
      nb=$(_wt_nested_base "$WT_ROOT/$nf[1]")
      nbehind=$(_wt_behind "$wtp/$nf[1]" "$nb")
      if _wt_mid_operation "$wtp/$nf[1]"; then
        _wt_warn "$name $nf[1] is mid-$(_wt_head_label "$wtp/$nf[1]") — left alone"
      elif [[ -z $nbehind || $nbehind == 0 ]]; then
        :
      elif (( ! rebase )); then
        _wt_info "$name $nf[1] is $nbehind behind"
      elif (( $(_wt_dirty_count "$wtp/$nf[1]" $WT_DIRTY_IGNORE) )); then
        _wt_warn "$name $nf[1] is $nbehind behind but dirty — skipped"
      elif git -C "$wtp/$nf[1]" rebase --quiet "$nb" >/dev/null 2>&1; then
        _wt_info "$name $nf[1] rebased (+$nbehind)"
      else
        git -C "$wtp/$nf[1]" rebase --abort 2>/dev/null
        nconflicts+="$name/$nf[1]"
        _wt_err "$name $nf[1] conflicts — rebase it by hand"
      fi
    done
  done

  (( ${#conflicts} )) && print -P "%F{9}conflicting:%f ${(j:, :)conflicts}"
  (( ${#nconflicts} )) && print -P "%F{9}conflicting (companions):%f ${(j:, :)nconflicts}"
  (( rebased )) && print -P "%F{8}rebased branches that are already pushed need a force-push; wt never pushes.%f"
  return 0
}

# ---------------------------------------------------------------------------- #
# rm
# ---------------------------------------------------------------------------- #

_wt_rm() {
  local name="" force=0 delbranch=0 dofold=1
  while (( $# )); do
    case $1 in
      -f|--force) force=1; shift ;;
      -b|--branch) delbranch=1; shift ;;
      --no-fold) dofold=0; shift ;;
      -*) _wt_die "unknown flag: $1"; return 1 ;;
      *) name=$1; shift ;;
    esac
  done
  [[ -z $name ]] && name=$(_wt_current)
  [[ -z $name ]] && { _wt_die "usage: wt rm <name> [--branch] [--force] (or run it from inside one)"; return 1 }

  local row=$(_wt_list | awk -F'\t' -v n="$name" '$1 == n')
  [[ -z $row ]] && { _wt_die "no worktree named $name"; return 1 }
  local -a f=(${(@ps:\t:)row})
  local wtp=$f[2] branch=$f[3] locked=$f[4]

  local merged=0 pr_merged=0 folded=0
  local -a seeded=(${(f)"$(_wt_seeded_paths)"})
  local -a pr=()

  if (( ! force )); then
    local n ustate

    [[ -n $locked ]] && { _wt_die "$name is locked — wt unlock $name, or --force"; return 1 }

    # Uncommitted work is the only thing removal can actually destroy, so it
    # comes first and says where it lives.
    n=$(_wt_dirty_count "$wtp" $WT_DIRTY_IGNORE)
    (( n )) && { _wt_die "$n uncommitted change(s) exist only in $wtp — commit them, or --force to discard"; return 1 }
    local -a stray=(${(f)"$(_wt_stray_untracked "$wtp" $seeded)"})
    stray=(${stray:#})
    if (( ${#stray} )); then
      _wt_err "these files exist only in $wtp:"
      print -rl -- ${stray[1,10]/#/    }
      _wt_err "add them, delete them, or --force to discard"
      return 1
    fi

    # Ask the forge before counting commits: after a squash merge the branch's
    # commits are in the trunk by content but never by ancestry, so the count
    # below would refuse forever.
    pr=(${(@ps:\t:)"$(_wt_pr "$WT_ROOT" "$branch")"})
    case $pr[1] in
      OPEN)   _wt_die "PR #$pr[2] for $branch is still open — merge it, or --force"; return 1 ;;
      MERGED) merged=1 pr_merged=1
              _wt_info "PR #$pr[2] is merged — squashed, so the local commits are expectedly not in $WT_TRUNK" ;;
      CLOSED) _wt_warn "PR #$pr[2] was closed without merging" ;;
    esac

    # second opinion that needs no network, and the only one available offline
    if (( ! merged )) && _wt_contained "$wtp" "$branch" "$WT_BASE"; then
      merged=1
      _wt_info "$branch adds nothing to $WT_BASE — its changes are already there"
    fi

    if (( ! merged )); then
      n=$(_wt_unpushed "$wtp" "$branch" "$WT_BASE")
      ustate=$(_wt_upstream_state "$wtp" "$branch")
      if (( n )); then
        if [[ $ustate == gone ]]; then
          _wt_err "$name has $n commit(s) not in $WT_BASE and its remote branch is gone,"
          _wt_err "which usually means a squash merge — confirm, then --force"
        else
          _wt_err "$name has $n unpushed commit(s) — push, or --force"
        fi
        return 1
      fi
    fi

    _wt_rm_check_nested "$wtp" "$name" "$pr_merged" "$dofold" "$pr[2]" || return 1
    folded=$WT_FOLDED
  fi

  [[ $PWD == $wtp* ]] && cd "$WT_ROOT"

  _wt_head "removing %B$name%b"
  _wt_unseed "$wtp"
  [[ -n $locked ]] && git -C "$WT_ROOT" worktree unlock "$wtp" 2>/dev/null

  _wt_nested_detach "$wtp" || return 1
  git -C "$WT_ROOT" worktree remove --force "$wtp" || { _wt_die "could not remove $wtp"; return 1 }
  git -C "$WT_ROOT" worktree prune

  local line
  local -a nf
  for line in ${(f)"$(_wt_nested_specs)"}; do
    nf=(${(@ps:\t:)line})
    [[ $nf[2] == mirror ]] && git -C "$WT_ROOT/$nf[1]" worktree prune 2>/dev/null
  done

  if (( delbranch )); then
    if git -C "$WT_ROOT" branch -d "$branch" 2>/dev/null; then
      _wt_info "deleted branch $branch"
    elif (( merged )); then
      # -d judges by ancestry, which a squash merge never satisfies; that the
      # work is in the trunk is the better authority
      git -C "$WT_ROOT" branch -D "$branch" >/dev/null && _wt_info "deleted branch $branch (already in $WT_TRUNK)"
    elif (( force )); then
      git -C "$WT_ROOT" branch -D "$branch" >/dev/null && _wt_warn "force-deleted unmerged $branch"
    else
      _wt_warn "kept $branch — not merged into $WT_TRUNK"
    fi
  fi

  # A mirror just folded into its trunk is merged cruft, so it goes whether or
  # not --branch was given.
  if (( delbranch || folded )); then
    for line in ${(f)"$(_wt_nested_specs)"}; do
      nf=(${(@ps:\t:)line})
      [[ $nf[2] == mirror ]] || continue
      local src=$WT_ROOT/$nf[1] nb=$(_wt_nested_base "$WT_ROOT/$nf[1]")
      git -C "$src" show-ref --verify --quiet "refs/heads/$branch" || continue
      if git -C "$src" branch -d "$branch" 2>/dev/null; then
        _wt_info "deleted $nf[1] branch $branch"
      elif _wt_contained "$src" "$branch" "$nb"; then
        git -C "$src" branch -D "$branch" >/dev/null &&
          _wt_info "deleted $nf[1] branch $branch (already in its trunk)"
      elif (( force )); then
        git -C "$src" branch -D "$branch" >/dev/null &&
          _wt_warn "force-deleted unmerged $nf[1] branch $branch"
      else
        _wt_warn "kept $nf[1] branch $branch — merge it into its trunk first"
      fi
    done
  fi

  _wt_ok "$name gone"
}

# The companion side of the removal guard. Sets WT_FOLDED when it squash-merged
# something, so the caller knows the mirror branch is now cruft.
_wt_rm_check_nested() {
  local wtp=$1 name=$2 pr_merged=$3 dofold=$4 prnum=$5 line n nbranch nb
  local -a f
  WT_FOLDED=0
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror && -d $wtp/$f[1] ]] || continue
    nbranch=$(_wt_head_label "$wtp/$f[1]")
    nb=$(_wt_nested_base "$WT_ROOT/$f[1]")

    n=$(_wt_dirty_count "$wtp/$f[1]" $WT_DIRTY_IGNORE)
    (( n )) && { _wt_die "$f[1] has $n uncommitted change(s), which exist only in $wtp/$f[1] — commit them there, or --force"; return 1 }

    n=$(_wt_unpushed "$wtp/$f[1]" "$nbranch" "$nb")
    (( n )) || continue
    _wt_contained "$wtp/$f[1]" "$nbranch" "$nb" && continue

    case $f[3] in
      ignore) continue ;;
      fold)
        # Already folded by hand? Then the mirror is merely stale, and trying to
        # fold again would only re-raise the same conflict.
        if _wt_work_in_base "$wtp/$f[1]" "$nbranch" "$nb"; then
          _wt_info "$f[1] is stale but adds nothing to its trunk"
          continue
        fi
        # Gated on the PR, not on mere containment: a branch whose work was
        # abandoned also "adds nothing", and the policy for an abandoned mirror
        # is to drop it, not to fold its contents in silently.
        if (( pr_merged && dofold )); then
          _wt_fold "$f[1]" "$nbranch" "$prnum" "$name" || return 1
          WT_FOLDED=1
          continue
        fi
        _wt_die "$f[1] is ahead of its trunk by $n commit(s) on $nbranch — merge it first, or --force"
        return 1 ;;
      *)
        _wt_work_in_base "$wtp/$f[1]" "$nbranch" "$nb" &&
          { _wt_info "$f[1] is stale but adds nothing to its trunk"; continue }
        _wt_die "$f[1] is ahead of its trunk by $n commit(s) on $nbranch — merge it first, or --force"
        return 1 ;;
    esac
  done
  return 0
}

# ---------------------------------------------------------------------------- #
# lock / unlock / seed / which / gc
# ---------------------------------------------------------------------------- #

_wt_lock() {
  local name=${1:-$(_wt_current)} reason=${2:-wip} wtp
  [[ -z $name ]] && { _wt_die "usage: wt lock [name] [reason]"; return 1 }
  wtp=$(_wt_path_of "$name")
  [[ -z $wtp ]] && { _wt_die "no worktree named $name"; return 1 }
  git -C "$WT_ROOT" worktree lock --reason "$reason" "$wtp" || return 1
  _wt_mark_all "$wtp" "$name" "$(git -C $wtp rev-parse --abbrev-ref HEAD)"
  _wt_ok "$name locked ($reason) — wt rm needs --force now"
}

_wt_unlock() {
  local name=${1:-$(_wt_current)} wtp
  [[ -z $name ]] && { _wt_die "usage: wt unlock [name]"; return 1 }
  wtp=$(_wt_path_of "$name")
  [[ -z $wtp ]] && { _wt_die "no worktree named $name"; return 1 }
  git -C "$WT_ROOT" worktree unlock "$wtp" && _wt_ok "$name unlocked"
}

_wt_reseed() {
  local name=${1:-$(_wt_current)} wtp
  [[ -z $name ]] && { _wt_die "usage: wt seed [name]"; return 1 }
  wtp=$(_wt_path_of "$name")
  [[ -z $wtp ]] && { _wt_die "no worktree named $name"; return 1 }
  _wt_seed "$wtp"
  _wt_allow_direnv "$wtp"
}

_wt_which() {
  local top name
  if [[ $1 == --path ]]; then
    top=$(_wt_wt_root_of_pwd) || return 1
    [[ -z $top ]] && return 1
    print -r -- $top
    return 0
  fi
  if [[ $1 == --repo ]]; then
    print -r -- $WT_REPO
    return 0
  fi
  if [[ $1 == --root ]]; then
    print -r -- $WT_ROOT
    return 0
  fi
  name=$(_wt_current)
  [[ -z $name ]] && return 1
  print -r -- $name
}

_wt_free_kb() { df -k "$WT_HOME" 2>/dev/null | tail -1 | awk '{print $4}' }

_wt_gc() {
  (( ${#WT_GC} )) || { _wt_info "no gc_paths in $WT_REPO's profile — nothing to drop"; return 0 }
  local -a rows=() f hits
  local name wtp line pat hit size before after dropped=0

  if (( $# )); then
    for name in "$@"; do
      case $name in
        main|primary) rows+="primary	$WT_ROOT" ;;
        *) wtp=$(_wt_path_of "$name")
           [[ -z $wtp ]] && { _wt_die "no worktree named $name"; return 1 }
           rows+="$name	$wtp" ;;
      esac
    done
  else
    rows+="primary	$WT_ROOT"
    for line in ${(f)"$(_wt_list)"}; do
      f=(${(@ps:\t:)line}); rows+="$f[1]	$f[2]"
    done
  fi

  _wt_head "dropping cache paths"
  before=$(_wt_free_kb)

  for line in $rows; do
    f=(${(@ps:\t:)line})
    name=$f[1] wtp=$f[2]
    hits=()
    for pat in $WT_GC; do
      hits+=(${~wtp}/${~pat}(N))
    done
    if (( ! ${#hits} )); then
      _wt_info "$name: nothing to drop"
      continue
    fi
    for hit in $hits; do
      size=$(du -sh "$hit" 2>/dev/null | cut -f1)
      rm -rf "$hit" && (( ++dropped )) && _wt_info "$name: ${hit#$wtp/} (${size:-?})"
    done
  done

  after=$(_wt_free_kb)
  _wt_ok "dropped $dropped path(s), $(( (after - before) / 1024 )) MB reclaimed"
}

# ---------------------------------------------------------------------------- #
# doctor
# ---------------------------------------------------------------------------- #

_wt_doctor() {
  local line issues=0 prunable
  local -a f seeded=(${(f)"$(_wt_seeded_paths)"})

  print -P "%B%F{12}$WT_REPO%f%b $WT_ROOT %F{8}(trunk $WT_TRUNK, base $WT_BASE)%f"
  [[ -n $WT_PROFILE_PATH ]] &&
    print -P "%F{8}profile: ${WT_PROFILE_PATH/#$HOME/~}%f" ||
    print -P "%F{8}profile: none — running on defaults. wt init writes one.%f"

  # half the prerequisites live in the primary, not in the worktrees
  local pbranch=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD)
  [[ $pbranch != $WT_TRUNK ]] &&
    { _wt_warn "on $pbranch, not $WT_TRUNK — move it out with: wt adopt $pbranch"; (( ++issues )) }
  git -C "$WT_ROOT" rev-parse --verify --quiet "$WT_BASE^{commit}" >/dev/null 2>&1 ||
    { _wt_warn "$WT_BASE does not resolve"; (( ++issues )) }
  [[ -d $WT_HOME ]] || { _wt_warn "worktree home $WT_HOME does not exist — wt setup"; (( ++issues )) }

  local -a missing=(${(f)"$(_wt_exclude_missing)"})
  missing=(${missing:#})
  (( ${#missing} )) &&
    { _wt_warn "not in .git/info/exclude (shared by every worktree): ${(j:, :)missing} — wt setup"; (( ++issues )) }

  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ -e $WT_ROOT/$f[1]/.git ]] ||
      { _wt_warn "nested $f[2] '$f[1]' is not a git repository in the primary"; (( ++issues )) }
  done

  prunable=$(git -C "$WT_ROOT" worktree list --porcelain | grep -c '^prunable')
  (( prunable )) && { _wt_warn "$prunable stale worktree registration(s) — wt sync clears them"; (( ++issues )) }

  # Declared outside the loop: a bare `local x` on an already-local name prints
  # "x=value" in zsh instead of redeclaring, so this leaks on the 2nd worktree.
  local name wtp branch n pinned rel nline
  local -a nf badges pr
  for line in ${(f)"$(_wt_list)"}; do
    f=(${(@ps:\t:)line})
    name=$f[1] wtp=$f[2] branch=$f[3]
    print -P "%B%F{12}$name%f%b $wtp"
    for nline in ${(f)"$(_wt_nested_specs)"}; do
      nf=(${(@ps:\t:)nline})
      [[ $nf[2] == mirror ]] || continue
      [[ -d $wtp/$nf[1] ]] || { _wt_warn "no $nf[1] worktree"; (( ++issues )) }
      [[ -d $wtp/$nf[1] ]] && _wt_mid_operation "$wtp/$nf[1]" &&
        { _wt_warn "$nf[1] is mid-$(_wt_head_label "$wtp/$nf[1]")"; (( ++issues )) }
    done
    for rel in $WT_LINK; do
      [[ -e $WT_ROOT/$rel ]] || continue
      [[ -L $wtp/$rel ]] || { _wt_warn "$rel is not linked — wt seed $name"; (( ++issues )) }
    done
    _wt_mid_operation "$wtp" &&
      { _wt_warn "a $(_wt_head_label "$wtp") is in progress here — finish it or abort"; (( ++issues )) }
    pinned=$(_wt_pinned "$wtp")
    [[ -n $pinned && $pinned != $branch ]] &&
      { _wt_warn "created for $pinned but sitting on $branch"; (( ++issues )) }
    badges=(${(f)"$(_wt_run_probes "$wtp" "$name" "$branch")"})
    badges=(${badges:#})
    (( ${#badges} )) && print -P "  ${(j: :)badges}"
    pr=(${(@ps:\t:)"$(_wt_pr "$WT_ROOT" "$branch")"})
    [[ $pr[1] == MERGED ]] && _wt_info "PR #$pr[2] is merged — wt rm $name --branch"
  done

  _wt_scan_ports
  local owner running=0
  for owner in ${(k)WT_RUN}; do
    [[ $owner == external ]] && continue
    running=1
    print -P "%B%F{14}▶ $owner%f%b is serving ${WT_RUN[$owner]// /, }${WT_SHARED_NOTE:+ — $WT_SHARED_NOTE}"
  done
  (( running )) || (( ! ${#WT_PORT_LABEL} )) ||
    print -P "%F{8}nothing is listening on the known ports${WT_SHARED_NOTE:+ — $WT_SHARED_NOTE}%f"

  (( issues )) && print -P "%F{11}$issues thing(s) to look at%f" || _wt_ok "nothing to report"
  return 0
}
