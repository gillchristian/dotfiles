# ---------------------------------------------------------------------------- #
# profiles and the registry
#
# A profile describes one repository. It lives at <primary>/.wt.zsh so it can be
# versioned with the code it describes; a repo that will not take the file falls
# back to ~/.config/wt/profiles/<name>.zsh. Either way it is read from the
# PRIMARY checkout, which always exists — that is what makes it safe for `wt
# new` to depend on, before the worktree it is creating is there.
#
# The registry is the other half, and stays deliberately thin: one absolute path
# per line, the primary checkout of each repo you have opted in. It exists for
# the two things $PWD cannot answer — resolving a profile from outside any
# checkout, and enumerating repos for the cross-repo picker.
#
# Trust: a profile is shell code (probes are commands). Nothing is ever
# auto-discovered or auto-sourced; a repo is only read after you registered it
# by hand or ran `wt init` in it. Same bargain as direnv.
# ---------------------------------------------------------------------------- #

WT_REGISTRY=${WT_REGISTRY:-${XDG_CONFIG_HOME:-$HOME/.config}/wt/repos}
WT_PROFILE_DIR=${WT_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/wt/profiles}

# ---------------------------------------------------------------------------- #
# registry
# ---------------------------------------------------------------------------- #

_wt_registry_read() {
  [[ -f $WT_REGISTRY ]] || return 0
  setopt local_options extended_glob
  local line
  for line in ${(f)"$(<$WT_REGISTRY)"}; do
    line=${line%%\#*}
    line=${line##[[:space:]]#}
    line=${line%%[[:space:]]#}
    [[ -z $line ]] && continue
    print -r -- ${~line}
  done
}

_wt_registered() {
  local r
  for r in ${(f)"$(_wt_registry_read)"}; do
    [[ ${r%/} == ${1%/} ]] && return 0
  done
  return 1
}

_wt_registry_add() {
  local root=${1:A}
  _wt_registered "$root" && { _wt_info "already registered: $root"; return 0 }
  mkdir -p "${WT_REGISTRY:h}"
  [[ -f $WT_REGISTRY ]] ||
    print -r -- "# wt registry — one primary checkout per line. wt repos add|rm" > "$WT_REGISTRY"
  print -r -- "$root" >> "$WT_REGISTRY"
  _wt_ok "registered $root"
}

_wt_registry_rm() {
  local root=${1:A} tmp
  [[ -f $WT_REGISTRY ]] || { _wt_die "no registry at $WT_REGISTRY"; return 1 }
  tmp=$(mktemp "${TMPDIR:-/tmp}/wt-reg.XXXXXX") || return 1
  grep -v -x -F -- "$root" "$WT_REGISTRY" > "$tmp" && mv "$tmp" "$WT_REGISTRY"
  _wt_ok "unregistered $root (the .wt.zsh and the worktrees are untouched)"
}

_wt_repos() {
  local sub=${1:-list} root file n
  case $sub in
    add)  shift; _wt_registry_add "${1:-$(git rev-parse --show-toplevel 2>/dev/null || print -r -- $PWD)}" ;;
    rm)   shift; _wt_registry_rm  "${1:-$(_wt_common_root)}" ;;
    list|"")
      n=0
      printf "%-16s  %-8s  %-42s  %s\n" NAME TRUNK PRIMARY PROFILE
      for root in ${(f)"$(_wt_registry_read)"}; do
        (( ++n ))
        file=$(_wt_profile_file "$root")
        printf "%-16s  %-8s  %-42s  %s\n" \
          "$(_wt_fit "$(_wt_profile_name "$root")" 16)" \
          "$(_wt_fit "$(_wt_profile_peek "$root" trunk)" 8)" \
          "$(_wt_fit "$root" 42)" \
          "${file:-(defaults)}"
      done
      (( n )) || print -P "%F{8}(nothing registered — run wt init in a repo)%f"
      ;;
    *) _wt_die "usage: wt repos [list|add [path]|rm [path]]"; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------- #
# finding the profile that owns $PWD
# ---------------------------------------------------------------------------- #

_wt_profile_file() {
  local root=$1
  [[ -f $root/.wt.zsh ]] && { print -r -- "$root/.wt.zsh"; return 0 }
  [[ -f $WT_PROFILE_DIR/${root:t}.zsh ]] && { print -r -- "$WT_PROFILE_DIR/${root:t}.zsh"; return 0 }
  return 1
}

# name without a full load — used by listings
_wt_profile_name() {
  local n=$(_wt_profile_peek "$1" name)
  print -r -- ${n:-${1:t}}
}

# one value out of a profile without disturbing the caller's scope
_wt_profile_peek() {
  local root=$1 key=$2 file
  file=$(_wt_profile_file "$root") || return 0
  ( local name home trunk remote naming ticket ticket_case name_case seed_default add_filter \
          post_new label_dir label_format shared_note pr
    local -a protected link skip nested ports gc_paths dirty_ignore
    wt_probe() { : }
    source "$file" 2>/dev/null
    print -r -- ${(P)key} )
}

# The common gitdir is shared by every linked worktree, so its parent is always
# the primary. Walking up from there also resolves a nested repo (whose own
# primary sits inside the parent's primary) back to the repo that owns it.
_wt_owner_root() {
  local d=${1:-$PWD} r i
  for i in 1 2 3; do
    r=$(_wt_common_root "$d") || break
    _wt_registered "$r" && { print -r -- $r; return 0 }
    d=${r:h}
    [[ -z $d || $d == / ]] && break
  done
  # not inside a checkout (or not registered): fall back to a path match, which
  # also covers standing in the worktree container directory itself
  local root home
  for root in ${(f)"$(_wt_registry_read)"}; do
    [[ $PWD == ${root%/} || $PWD == ${root%/}/* ]] && { print -r -- $root; return 0 }
  done
  for root in ${(f)"$(_wt_registry_read)"}; do
    home=$(_wt_profile_peek "$root" home)
    home=${home:-${root:h}/${root:t}-wt}
    [[ $PWD == ${home%/} || $PWD == ${home%/}/* ]] && { print -r -- $root; return 0 }
  done
  return 1
}

_wt_root_for_name() {
  local want=$1 root
  for root in ${(f)"$(_wt_registry_read)"}; do
    [[ $(_wt_profile_name "$root") == $want || ${root:t} == $want ]] &&
      { print -r -- $root; return 0 }
  done
  return 1
}

# ---------------------------------------------------------------------------- #
# loading
#
# The bare names below are local to this function, so a profile's `trunk=master`
# never escapes into the shell. Everything downstream reads the WT_* copies,
# which wt() declared local for the length of one invocation.
# ---------------------------------------------------------------------------- #

_wt_detect_trunk() {
  local root=$1 remote=$2 h
  h=$(git -C "$root" symbolic-ref --short "refs/remotes/$remote/HEAD" 2>/dev/null)
  [[ -n $h ]] && { print -r -- ${h#$remote/}; return }
  local b
  for b in main master trunk; do
    _wt_has_remote "$root" "$remote/$b" && { print -r -- $b; return }
  done
  for b in main master trunk; do
    _wt_has_local "$root" "$b" && { print -r -- $b; return }
  done
  print -r -- $(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
}

_wt_detect_remote() {
  local root=$1
  git -C "$root" remote get-url origin >/dev/null 2>&1 && { print -r -- origin; return }
  print -r -- ${${(f)"$(git -C $root remote 2>/dev/null)"}[1]:-origin}
}

_wt_load() {
  local root=$1 file
  local name home trunk remote naming ticket ticket_case name_case seed_default \
        add_filter post_new label_dir label_format shared_note pr
  local -a protected link skip nested ports gc_paths dirty_ignore

  # A profile may define wt_name() to compute a directory name itself. Functions
  # are not scoped by `local`, so clear both names first — otherwise one repo's
  # hook would still be defined while another repo is loaded — and stash it
  # under a private name straight after.
  unfunction wt_name _wt_name_hook 2>/dev/null

  if file=$(_wt_profile_file "$root"); then
    source "$file" || { _wt_die "profile failed to load: $file"; return 1 }
    WT_PROFILE_PATH=$file
  else
    WT_PROFILE_PATH=""
  fi

  if (( $+functions[wt_name] )); then
    functions[_wt_name_hook]=$functions[wt_name]
    unfunction wt_name
  fi

  WT_ROOT=${root%/}
  WT_REPO=${name:-${WT_ROOT:t}}
  WT_REMOTE=${remote:-$(_wt_detect_remote "$WT_ROOT")}
  WT_TRUNK=${trunk:-$(_wt_detect_trunk "$WT_ROOT" "$WT_REMOTE")}
  WT_BASE=$WT_REMOTE/$WT_TRUNK
  _wt_has_remote "$WT_ROOT" "$WT_BASE" || WT_BASE=$WT_TRUNK
  WT_HOME=${home:-${WT_ROOT:h}/${WT_ROOT:t}-wt}
  WT_NAMING=${naming:-ticket}
  WT_TICKET=${ticket:-'[A-Za-z]+-[0-9]+'}
  WT_NAME_CASE=${name_case:-${ticket_case:-keep}}   # ticket_case is the old spelling
  WT_SEED_DEFAULT=${seed_default:-clone}
  WT_ADD_FILTER=$add_filter
  WT_POST_NEW=$post_new
  WT_LABEL_DIR=$label_dir
  WT_LABEL_FORMAT=${label_format:-%n}
  WT_SHARED_NOTE=$shared_note
  WT_PR=${pr:-1}

  # NOT ${protected:-a b c}: zsh does not word-split, so the default would
  # arrive as the single element "master main master" and match nothing.
  if (( ${#protected} )); then
    WT_PROTECTED=($protected)
  else
    WT_PROTECTED=($WT_TRUNK main master)
  fi
  WT_PROTECTED=(${(u)WT_PROTECTED})
  WT_LINK=($link)
  WT_SKIP=($skip)
  WT_NESTED=($nested)
  WT_GC=($gc_paths)
  # pathspecs excluded from the dirty count, for files an editor rewrites on its own
  WT_DIRTY_IGNORE=()
  local p
  for p in $dirty_ignore; do WT_DIRTY_IGNORE+=":(exclude)$p"; done

  WT_PORT_LABEL=()
  for p in $ports; do
    [[ $p == *:* ]] && WT_PORT_LABEL[${p%%:*}]=${p#*:}
  done

  # nested repos never get seeded — they get their own worktree or symlink
  local spec
  for spec in $WT_NESTED; do WT_SKIP+=(${spec%%:*}); done
  return 0
}

# Resolve which repo this invocation is about, then load it.
_wt_use() {
  local want=$1 root
  if [[ -n $want ]]; then
    root=$(_wt_root_for_name "$want") ||
      { _wt_err "no registered repo called $want"; _wt_repos list; return 1 }
  elif root=$(_wt_owner_root); then
    :
  elif [[ -n $WT_PROFILE ]] && root=$(_wt_root_for_name "$WT_PROFILE"); then
    :
  else
    local -a all=(${(f)"$(_wt_registry_read)"})
    local here
    if (( ${#all} == 0 )); then
      _wt_err "nothing registered yet — cd into a repo and run: wt init"
      return 1
    elif here=$(_wt_common_root); then
      # Standing in a git repo that is not registered. Falling back to "the only
      # registered one" here would act on a different repository than the one in
      # front of you — the most expensive way to be convenient.
      _wt_err "${here:t} is not registered. Run \`wt init\` here, or name one with -R:"
      _wt_repos list
      return 1
    elif (( ${#all} == 1 )); then
      root=$all[1]
    else
      _wt_err "$PWD is not in a registered repo; say which with -R <name>:"
      _wt_repos list
      return 1
    fi
  fi
  [[ -d $root ]] || { _wt_die "registered repo is missing: $root"; return 1 }
  _wt_load "$root"
}

# ---------------------------------------------------------------------------- #
# init — write a starting profile by looking at the repo
#
# Everything here is a guess meant to be edited. It exists because the cost of
# adopting the tool for repo #3 should be reading twenty lines, not writing them.
# ---------------------------------------------------------------------------- #

_wt_guess_disposition() {
  local rel=${1%/}
  case ${rel:t} in
    node_modules|target|dist|build|out|.next|.nuxt|.vite|.turbo|.parcel-cache|.cache|\
    elm-stuff|.elm-land|vendor|__pycache__|.venv|venv|.gradle|Pods|DerivedData|.stack-work|\
    .mypy_cache|.pytest_cache|coverage|.tox|_build|deps|zig-cache|zig-out)
      print -r -- clone; return ;;
    .DS_Store|Thumbs.db|tmp|temp|logs|.review|.terraform)
      print -r -- skip; return ;;
    .envrc|.env|CLAUDE.md|AGENTS.md)
      print -r -- link; return ;;
  esac
  case $rel in
    *.log|*/log/*|*/tmp/*|*.lock)          print -r -- skip ;;
    *.local|*.local.*|local.*|*settings.local.*|*.code-workspace|*/.claude/*)
                                           print -r -- link ;;
    *)                                     print -r -- unknown ;;
  esac
}

_wt_guess_ports() {
  # Depth-limited on purpose: a `**` glob here would walk node_modules.
  local root=$1 f p
  local -a found=() hits
  for f in $root/package.json(N)      $root/*/package.json(N)      $root/*/*/package.json(N) \
           $root/vite.config.*(N)     $root/*/vite.config.*(N)     $root/*/*/vite.config.*(N) \
           $root/*.go(N)              $root/*/*.go(N)              $root/*/*/*.go(N); do
    [[ -f $f ]] || continue
    [[ $f == */node_modules/* ]] && continue
    hits=(${(f)"$(grep -oE '(--port[=[:space:]]+|PORT=|PORT", "|"?port"?:[[:space:]]*)[0-9]{2,5}' $f 2>/dev/null |
                    grep -oE '[0-9]{2,5}' | sort -u)"})
    for p in $hits; do
      [[ -n $p ]] && found+="$p:${${f:h}:t}"
    done
  done
  print -rl -- ${(u)found}
}

# "<naming>\t<name_case>", guessed from how branches are actually named here:
# ticket-shaped ones win, else slashed ones suggest the last segment, else the
# branch name is already short enough to use whole.
_wt_guess_naming() {
  setopt local_options no_bash_rematch
  local root=$1 n
  local -a names=(${(f)"$(git -C $root for-each-ref --count=40 --sort=-committerdate \
                            --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"})
  names=(${names:#*HEAD})
  # Strip the remote prefix first: `origin/mac` is not a slashed branch name,
  # and counting it as one turns every repo into a `last` repo.
  local r
  local -a remotes=(${(f)"$(git -C $root remote 2>/dev/null)"})
  for r in $remotes; do names=(${names/#$r\//}) ; done
  names=(${(u)names:#(main|master|trunk)})
  local -i hit=0 upper=0 slashed=0 total=0
  for n in $names; do
    (( ++total ))
    [[ $n == */* ]] && (( ++slashed ))
    [[ $n =~ '[A-Za-z]+-[0-9]+' ]] || continue
    (( ++hit ))
    [[ $MATCH == [A-Z]* ]] && (( ++upper ))
  done
  if (( hit >= 2 && hit * 2 >= total )); then
    # most tickets already upper in the branch name -> keep; lowercase -> upper
    # printf, not print -r: the latter emits a literal backslash-t
    (( upper * 2 >= hit )) && printf 'ticket\tkeep\n' || printf 'ticket\tupper\n'
  elif (( total && slashed * 2 >= total )); then
    printf 'last\tkeep\n'
  else
    printf 'slug\tkeep\n'
  fi
}

_wt_find_nested() {
  local root=$1 d
  for d in $root/*/.git(N) $root/*/*/.git(N); do
    print -r -- ${${d:h}#$root/}
  done
}

_wt_init() {
  local force=0 root
  while (( $# )); do
    case $1 in
      -f|--force) force=1; shift ;;
      *) root=$1; shift ;;
    esac
  done
  root=${root:-$(git rev-parse --show-toplevel 2>/dev/null)}
  [[ -z $root ]] && { _wt_die "not inside a git repository — cd into one, or: wt init <path>"; return 1 }
  root=${root:A}

  local out=$root/.wt.zsh
  [[ -e $out ]] && (( ! force )) &&
    { _wt_die "$out already exists — edit it, or: wt init --force"; return 1 }

  local remote=$(_wt_detect_remote "$root")
  local trunk=$(_wt_detect_trunk "$root" "$remote")
  local -a guess=(${(@ps:\t:)"$(_wt_guess_naming "$root")"})
  local gnaming=${guess[1]:-ticket} gcase=${guess[2]:-keep}

  _wt_head "reading %B${root:t}%b"
  _wt_info "trunk: $trunk (remote $remote)"
  _wt_info "branch naming looks like: $gnaming"

  local -a link=() skip=() clone=() unknown=() nested=() ports=()
  local rel disp
  for rel in ${(f)"$(git -C $root status --porcelain --ignored=matching 2>/dev/null | sed -n 's/^!! //p')"}; do
    rel=${rel%/}
    [[ -z $rel ]] && continue
    disp=$(_wt_guess_disposition "$rel")
    case $disp in
      link)    link+=$rel ;;
      skip)    skip+=$rel ;;
      clone)   clone+=$rel ;;
      unknown) unknown+=$rel ;;
    esac
  done
  # Untracked-and-local config is the other half of what wants linking, and it
  # is NOT in the ignored list — that is exactly the situation `wt setup` fixes
  # by writing .git/info/exclude. Only link candidates are taken from here;
  # anything else untracked is someone's work in progress, not ours to classify.
  for rel in ${(f)"$(git -C $root ls-files --others --exclude-standard --directory 2>/dev/null)"}; do
    rel=${rel%/}
    [[ -z $rel ]] && continue
    [[ $(_wt_guess_disposition "$rel") == link ]] && link+=$rel
  done
  link=(${(u)link})

  nested=(${(f)"$(_wt_find_nested $root)"})
  ports=(${(f)"$(_wt_guess_ports $root)"})
  # a nested repo is never a link candidate — it gets its own worktree
  local nrel
  for nrel in $nested; do link=(${link:#$nrel}); done

  _wt_info "ignored paths: ${#clone} to clone, ${#link} to link, ${#skip} to skip, ${#unknown} unclassified"
  (( ${#nested} )) && _wt_info "nested repositories: ${(j:, :)nested}"
  (( ${#ports} )) && _wt_info "ports: ${(j:, :)ports}"

  {
    print -r -- "# wt profile for ${root:t} — see \`wt help profile\`. Everything is optional."
    print -r -- "# Generated by \`wt init\` on $(date +%Y-%m-%d); the classifications are guesses."
    print -r -- ""
    print -r -- "trunk=$trunk"
    print -r -- "remote=$remote"
    print -r -- "home=\$HOME/${${root:h}/#$HOME\/}/${root:t}-wt"
    print -r -- ""
    print -r -- "# How a branch name becomes a directory name."
    print -r -- "#   ticket  a ticket pulled out of the branch: feat/ABC-12/x -> ABC-12"
    print -r -- "#   last    the last path segment:              feat/add-login -> add-login"
    print -r -- "#   first   the first path segment:             alice/thing    -> alice"
    print -r -- "#   slug    the whole branch, flattened:        feat/add-login -> feat-add-login"
    print -r -- "# A bare \`wt new login\` always gives you the branch AND directory 'login',"
    print -r -- "# and --as <name> overrides whatever this picks."
    print -r -- "naming=$gnaming"
    print -r -- "name_case=$gcase        # keep | upper | lower"
    if [[ $gnaming == ticket ]]; then
      print -r -- "ticket='[A-Za-z]+-[0-9]+'"
    else
      print -r -- "# ticket='[A-Za-z]+-[0-9]+'   # only consulted when naming=ticket"
    fi
    print -r -- ""
    print -r -- "# Seeding. Ignored paths not named here follow seed_default."
    print -r -- "seed_default=clone       # clone (APFS copy-on-write) | skip"
    if (( ${#link} )); then
      print -r -- "link=(   # symlinked to the primary: one source of truth"
      print -rl -- ${link/#/  }
      print -r -- ")"
    else
      print -r -- "link=()  # symlinked to the primary: one source of truth"
    fi
    if (( ${#skip} )); then
      print -r -- "skip=(   # never seeded: regenerated, or state that must not be shared"
      print -rl -- ${skip/#/  }
      print -r -- ")"
    else
      print -r -- "skip=()  # never seeded: regenerated, or state that must not be shared"
    fi
    if (( ${#unknown} )); then
      print -r -- ""
      print -r -- "# Unclassified — these will be cloned by seed_default. Move any that are"
      print -r -- "# config (link) or throwaway (skip) into the lists above:"
      print -rl -- ${unknown/#/#   }
    fi
    print -r -- ""
    print -r -- "# Companion repositories living inside the checkout."
    print -r -- "#   <path>:mirror[:fold|require-merged|ignore][:label]  own worktree, same branch name"
    print -r -- "#   <path>:link                                        symlinked to the primary"
    if (( ${#nested} )); then
      print -r -- "nested=("
      print -rl -- ${${nested/%/:mirror:require-merged}/#/  }
      print -r -- ")"
    else
      print -r -- "nested=()"
    fi
    print -r -- ""
    print -r -- "# Labels for the port scan. Attribution is by each listener's cwd, so a"
    print -r -- "# service on an unlisted port is still attributed to the right checkout;"
    print -r -- "# this list only names them and reports which expected ones are down."
    if (( ${#ports} )); then
      print -r -- "ports=(${(j: :)ports})"
    else
      print -r -- "ports=()   # e.g. (3000:web 5432:db)"
    fi
    print -r -- "# shared_note='the database on :5432 is shared across worktrees'"
    print -r -- ""
    print -r -- "# Probes add a badge to \`wt ls\`. The command runs with cwd set to the"
    print -r -- "# worktree; empty or 0 output means no badge, anything else replaces {}."
    print -r -- "# Available: \$WT_TRUNK \$WT_BASE \$WT_ROOT \$WT_NAME \$WT_BRANCH \$WT_PATH"
    print -r -- "#"
    print -r -- "# wt_probe mig '%F{13}mig:{}%f' \\"
    print -r -- "#   'git diff --name-only --diff-filter=A \$WT_BASE...HEAD -- db/migrations | wc -l'"
    print -r -- ""
    print -r -- "# Anything the strategies above cannot express — the branch arrives as \$1:"
    print -r -- "# wt_name() { print -r -- \${\${1##*/}%%-*} }"
    print -r -- ""
    print -r -- "# gc_paths=('target/*/incremental')   # pure cache, safe to delete"
    print -r -- "# post_new='npm install'              # run in each new worktree"
  } > "$out"

  _wt_ok "wrote $out"
  _wt_registry_add "$root"
  print -P "%F{8}review it, then: wt setup%f"
}

# ---------------------------------------------------------------------------- #
# setup — make the primary satisfy what the profile assumes
#
# There is no per-worktree .git/info/exclude: git reads only the shared one, in
# the common gitdir. So the entries that hide a nested repo and the symlinked
# config have to be written once, in the primary, and they apply everywhere.
# Directory patterns never match a symlink, which is why linked paths are written
# without a trailing slash and nested repos with one.
# ---------------------------------------------------------------------------- #

WT_MARK_BEGIN='# >>> wt managed — regenerated by `wt setup` >>>'
WT_MARK_END='# <<< wt managed <<<'

_wt_exclude_file() {
  local d
  d=$(git -C "$WT_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  print -r -- "$d/info/exclude"
}

# What the profile implies the exclude file must contain.
#
# The trailing slash matters and is not cosmetic: a directory pattern never
# matches a symlink. A mirror is a real directory in every worktree, so it gets
# the slash; a linked path is a symlink there, so it must not.
_wt_exclude_wanted() {
  local line p
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] && print -r -- "${f[1]%/}/" || print -r -- "${f[1]%/}"
  done
  for p in $WT_LINK; do print -r -- "${p%/}" ; done
  # An in-repo profile the repo has not adopted would otherwise sit in
  # `git status` forever. Excluding it does not stop an explicit `git add`, so
  # committing it later still works.
  if [[ $WT_PROFILE_PATH == $WT_ROOT/.wt.zsh ]] &&
     ! git -C "$WT_ROOT" ls-files --error-unmatch .wt.zsh >/dev/null 2>&1; then
    print -r -- ".wt.zsh"
  fi
}

_wt_exclude_missing() {
  local file=$(_wt_exclude_file) want
  local -a have=()
  [[ -f $file ]] && have=(${(f)"$(<$file)"})
  for want in ${(f)"$(_wt_exclude_wanted)"}; do
    [[ ${have[(Ie)$want]} -gt 0 ]] || print -r -- $want
  done
}

# Lines inside the managed block that the profile no longer asks for — so
# dropping a `link` entry actually takes its exclude line with it.
_wt_exclude_stale() {
  local file=$(_wt_exclude_file) line inblock=0
  local -a want=(${(f)"$(_wt_exclude_wanted)"})
  [[ -f $file ]] || return 0
  for line in ${(f)"$(<$file)"}; do
    [[ $line == $WT_MARK_BEGIN ]] && { inblock=1; continue }
    [[ $line == $WT_MARK_END ]] && { inblock=0; continue }
    (( inblock )) || continue
    [[ -z $line ]] && continue
    [[ ${want[(Ie)$line]} -gt 0 ]] || print -r -- $line
  done
}

_wt_setup() {
  local dry=0
  [[ $1 == (-n|--dry-run) ]] && dry=1

  _wt_head "setting up %B$WT_REPO%b ($WT_ROOT)"
  local changed=0

  # the trunk has to exist for every containment test in the tool to mean anything
  git -C "$WT_ROOT" rev-parse --verify --quiet "$WT_BASE^{commit}" >/dev/null 2>&1 ||
    _wt_warn "$WT_BASE does not resolve — fetch, or fix trunk= in the profile"

  if [[ ! -d $WT_HOME ]]; then
    if (( dry )); then
      _wt_info "would create $WT_HOME"
    else
      mkdir -p "$WT_HOME" && _wt_ok "created $WT_HOME"
    fi
    changed=1
  fi

  local -a missing=(${(f)"$(_wt_exclude_missing)"}) stale=(${(f)"$(_wt_exclude_stale)"})
  missing=(${missing:#}); stale=(${stale:#})
  if (( ${#missing} || ${#stale} )); then
    changed=1
    local file=$(_wt_exclude_file)
    if (( dry )); then
      (( ${#missing} )) && { _wt_info "would add to ${file/#$HOME/~}:"; print -rl -- ${missing/#/    } }
      (( ${#stale} )) && { _wt_info "would drop (no longer in the profile):"; print -rl -- ${stale/#/    } }
    else
      local -a keep=()
      local line inblock=0
      if [[ -f $file ]]; then
        for line in ${(f)"$(<$file)"}; do
          [[ $line == $WT_MARK_BEGIN ]] && { inblock=1; continue }
          [[ $line == $WT_MARK_END ]] && { inblock=0; continue }
          (( inblock )) || keep+=$line
        done
      fi
      mkdir -p "${file:h}"
      { print -rl -- $keep
        print -r -- "$WT_MARK_BEGIN"
        print -rl -- ${(f)"$(_wt_exclude_wanted)"}
        print -r -- "$WT_MARK_END" } > "$file"
      (( ${#missing} )) && _wt_ok "excluded ${(j:, :)missing} (${file/#$HOME/~})"
      (( ${#stale} )) && _wt_ok "dropped ${(j:, :)stale} — no longer in the profile"
      print -P "%F{8}the exclude file is shared by every linked worktree — this applies everywhere%f"
    fi
  fi

  # a mirror needs the companion repo to actually be there in the primary
  local spec npath mode
  for spec in $WT_NESTED; do
    npath=${spec%%:*}; mode=${${spec#*:}%%:*}
    if [[ ! -d $WT_ROOT/$npath/.git && ! -f $WT_ROOT/$npath/.git ]]; then
      _wt_warn "nested $mode '$npath' is not a git repository in the primary"
      changed=1
    fi
  done

  (( changed )) || _wt_ok "already set up"
  return 0
}
