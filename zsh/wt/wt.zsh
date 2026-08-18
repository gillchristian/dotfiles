# ############################################################################ #
#                                                                              #
# wt — git worktrees, per repository                                           #
#                                                                              #
# Git worktrees, one profile per repository. What a single-repo predecessor    #
# hardcoded now lives in a profile:                                            #
#                                                                              #
#   <primary>/.wt.zsh          the profile — versioned with the code           #
#   ~/.config/wt/repos         the registry — one primary checkout per line    #
#                                                                              #
# The profile is always read from the PRIMARY checkout, which is what lets     #
# `wt new` depend on it before the worktree it is creating exists.             #
#                                                                              #
# One constraint shapes most of this: nothing in .git/ varies per worktree.    #
# info/exclude, core.hooksPath, refs/stash, objects and remotes are all        #
# shared, and a per-worktree info/exclude is never read. So `wt setup` writes  #
# the exclude entries once in the primary, and the tool carries its own notion #
# of "I put this here" rather than asking git to ignore it locally.            #
#                                                                              #
#   wt help            commands       wt help profile   the profile format     #
#                                                                              #
# ############################################################################ #

WT_DIR=${${(%):-%x}:A:h}
source "$WT_DIR/lib/core.zsh"
source "$WT_DIR/lib/profile.zsh"
source "$WT_DIR/lib/seed.zsh"
source "$WT_DIR/lib/cmds.zsh"

# The profile DSL. Appends to arrays that wt() declares local, so a profile can
# only add probes for the length of one invocation.
wt_probe() {
  (( $# == 3 )) || { _wt_err "wt_probe needs <name> <format> <command>"; return 1 }
  WT_PROBE_NAME+=("$1"); WT_PROBE_FMT+=("$2"); WT_PROBE_CMD+=("$3")
}

# ---------------------------------------------------------------------------- #
# the cross-repo picker — the one view the single-repo tool could not offer
# ---------------------------------------------------------------------------- #

_wt_rows() {
  local pbranch=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s\t%s\t%s\t%s\n' "$WT_REPO" primary "$WT_ROOT" "$pbranch"
  local line
  local -a f
  for line in ${(f)"$(_wt_list)"}; do
    f=(${(@ps:\t:)line})
    printf '%s\t%s\t%s\t%s\n' "$WT_REPO" "$f[1]" "$f[2]" "$f[3]"
  done
}

_wt_pick_global() {
  (( $+commands[fzf] )) || { _wt_err "fzf not found"; return 1 }
  local root dest
  local -a rows=()
  for root in ${(f)"$(_wt_registry_read)"}; do
    rows+=(${(f)"$(wt -R "$(_wt_profile_name "$root")" _rows 2>/dev/null)"})
  done
  rows=(${rows:#})
  (( ${#rows} )) || { _wt_err "nothing registered yet — cd into a repo and run: wt init"; return 1 }
  dest=$(print -rl -- $rows |
    fzf --height 40% --reverse --inline-info --with-nth 1,2,4 --delimiter='\t' \
        --preview 'git -C {3} status --short --branch --untracked-files=no' | cut -f3)
  [[ -z $dest ]] && return 1
  cd "$dest"
  _wt_register_z "$dest"
}

# ---------------------------------------------------------------------------- #
# usage
# ---------------------------------------------------------------------------- #

_wt_usage() {
  if [[ $1 == profile ]]; then
    print -r -- 'wt — the profile format

A profile is zsh sourced from <primary>/.wt.zsh, or from
~/.config/wt/profiles/<name>.zsh when a repo will not take the file. Every key
is optional; `wt init` writes a starting one by looking at the repo.

  name=            display name                    (default: directory name)
  trunk=           the branch everything compares to  (default: from origin/HEAD)
  remote=          (default: origin)
  home=            where worktrees go               (default: <parent>/<name>-wt)
  protected=()     branches that stay in the primary  (default: trunk main master)

  naming=          how a branch name becomes a directory name (default ticket)
                     ticket  a ticket pulled out of it   feat/ABC-12/x  -> ABC-12
                     last    the last path segment       feat/add-login -> add-login
                     first   the first path segment      alice/thing    -> alice
                     slug    the whole branch flattened  feat/add-login -> feat-add-login
                   `wt new login` gives you the branch AND the directory
                   `login` under every strategy, and --as <name> beats all of them.
  ticket=          the regex, when naming=ticket (default [A-Za-z]+-[0-9]+). It
                   also makes `wt new ABC-12` search for an EXISTING branch
                   containing that ticket; under the other strategies a bare word
                   is simply the branch to create.
  name_case=       keep | upper | lower, applied to what the strategy extracted.
                   `ticket` falling back to the whole branch is left alone.
                   (`ticket_case=` is the older spelling and still works.)
  wt_name()        a function taking the branch on $1 and printing the directory
                   name. Overrides `naming` entirely.
  label_format=    what the prompt marker says: %n worktree, %p repo (default %n)

  seed_default=    clone | skip — what happens to an ignored path not named below
  link=()          symlinked to the primary: one source of truth
  skip=()          never seeded: regenerated, or state that must not be shared
  dirty_ignore=()  pathspecs excluded from the dirty count

  nested=()        companion repositories inside the checkout:
                     <path>:mirror[:fold|require-merged|ignore][:label]
                     <path>:link
                   A mirror gets its own worktree on a same-named branch, and
                   every question about it is asked against ITS trunk. On
                   teardown: fold squash-merges it in once the PR is merged,
                   require-merged refuses, ignore says nothing.

  ports=()         port:label, for the scan’s labels and its "down" line.
                   Attribution is by each listener’s cwd, so an unlisted port is
                   still attributed correctly — this list never goes stale in a
                   way that misattributes.
  shared_note=     one line appended wherever a running stack is reported
  label_dir=       directory level to name services after, e.g. systems

  gc_paths=()      globs of pure cache that `wt gc` may delete
  add_filter=      regex of noise to drop from `git worktree add` output
  post_new=        command run inside each new worktree
  pr=0             do not ask gh about pull requests

  wt_probe <name> <format> <command>
                   Adds a badge to `wt ls`. The command runs with cwd set to
                   the worktree; empty or 0 output means no badge, anything else
                   replaces {} in the format. Available in the command:
                   $WT_TRUNK $WT_BASE $WT_ROOT $WT_NAME $WT_BRANCH $WT_PATH
                   Debug one with: wt probe [probe] [name]

A profile is shell code and is only ever read for a repo you registered by hand
or with `wt init`. Nothing is auto-discovered.'
    return 0
  fi

  print -r -- 'wt — git worktrees, per repository

  wt                       pick a worktree with fzf and cd into it
                           (outside a registered repo, picks across all of them)
  wt <name>                cd into it, keeping the relative subdir
  wt primary               cd into the primary checkout
  wt -R <repo> <cmd>       act on another registered repo

  wt init [path]           write a starting .wt.zsh by looking at the repo,
                           and register it            --force  overwrite
  wt setup                 make the primary satisfy the profile: worktree home,
                           and the .git/info/exclude entries that hide the
                           companion repos and the symlinked config
                           -n  say what it would do
  wt repos [list|add|rm]   the registry

  wt new <branch>          worktree + companion worktrees + seed, then cd
                           --from <ref>   base a new branch on <ref>
                           --as <name>    name the worktree yourself
                           --no-seed      skip the build-state clone
  wt adopt [branch]        move the primary’s branch into a worktree, park it
                           on the trunk   --move-changes  carry uncommitted work
                                          --as <name>

  wt ls                    every worktree: branch, distance from trunk, state
  wt ports                 which checkout serves each port, and what runs there
  wt doctor                the primary’s prerequisites, then each worktree
  wt probe [probe] [name]  run the profile’s probes and show their raw output
  wt which [--path|--root|--repo]

  wt sync                  fetch, fast-forward the trunk, rebase clean worktrees
                           --no-rebase    only report
  wt lock [name] [reason]  protect it from wt rm and git prune
  wt unlock [name]
  wt seed [name]           re-run seeding on an existing worktree
  wt gc [name...]          delete the profile’s gc_paths
  wt rm [name]             companions first, then the worktree, then prune
                           --branch       also delete the branches
                           --no-fold      never squash-merge a companion
                           --force        skip the safety checks

BEHIND is how many commits the trunk has that the branch does not. STATE:

  ▶svc       serving that from this checkout (wt ports for detail)
  ~N         N modified tracked files     ?N     N untracked files (seeds aside)
  ↑N         N commits not pushed
  merged     the branch adds nothing to the trunk — done, `wt rm` will allow it
             (a squash merge keeps its commits out of the trunk forever, so
             counting them says "unpushed" for good; the merge result is checked)
  gone       ↑N and the remote branch was deleted, yet the work is NOT in
  <c>:X      companion <c> is on X — a branch, or rebasing/merging/detached
  <c>~ <c>↑  companion has modifications / unpushed commits
  locked     wt rm needs --force        pinned:X  HEAD drifted off X
  clean      none of the above

Anything else is a probe from the repo’s own profile — wt help profile.'
}

# ---------------------------------------------------------------------------- #
# entry point
#
# Every profile value is a local of this function. Helpers see them by zsh's
# dynamic scope, and nothing survives the call — which is what lets one shell
# drive several repositories without a "current repo" mode to get wrong.
# ---------------------------------------------------------------------------- #

wt() {
  local WT_ROOT WT_REPO WT_REMOTE WT_TRUNK WT_BASE WT_HOME WT_TICKET \
        WT_NAMING WT_NAME_CASE WT_SEED_DEFAULT WT_ADD_FILTER WT_POST_NEW \
        WT_LABEL_DIR WT_LABEL_FORMAT WT_SHARED_NOTE WT_PR WT_PROFILE_PATH \
        WT_FOLDED
  local -a WT_PROTECTED WT_LINK WT_SKIP WT_NESTED WT_GC WT_DIRTY_IGNORE \
           WT_PROBE_NAME WT_PROBE_FMT WT_PROBE_CMD
  local -A WT_PORT_LABEL WT_PORT_PID WT_PORT_CMD WT_PORT_WHERE \
           WT_PORT_SEEN WT_RUN

  local repo="" cmd
  while (( $# )); do
    case $1 in
      -R|--repo) repo=$2; shift 2 ;;
      *) break ;;
    esac
  done
  cmd=$1
  (( $# )) && shift

  # these do not need — or cannot have — a loaded profile
  case $cmd in
    help|-h|--help) _wt_usage "$@"; return 0 ;;
    init)           _wt_init "$@"; return $? ;;
    repos)          _wt_repos "$@"; return $? ;;
    _repos)         local r                                   # for completion
                    for r in ${(f)"$(_wt_registry_read)"}; do _wt_profile_name "$r"; done
                    return 0 ;;
  esac

  if ! _wt_use "$repo"; then
    # a bare `wt` outside any registered repo is still answerable: show them all
    [[ -z $cmd ]] && { _wt_pick_global; return $? }
    return 1
  fi

  case $cmd in
    "")             _wt_goto ;;
    new|n)          _wt_new "$@" ;;
    ls|list|l)      _wt_ls "$@" ;;
    sync|up)        _wt_sync "$@" ;;
    rm|remove|done) _wt_rm "$@" ;;
    lock)           _wt_lock "$@" ;;
    unlock)         _wt_unlock "$@" ;;
    adopt)          _wt_adopt "$@" ;;
    seed)           _wt_reseed "$@" ;;
    gc)             _wt_gc "$@" ;;
    ports)          _wt_ports "$@" ;;
    which)          _wt_which "$@" ;;
    doctor|dr)      _wt_doctor "$@" ;;
    setup)          _wt_setup "$@" ;;
    probe)          _wt_probe_cmd "$@" ;;
    _names)         _wt_names ;;
    _rows)          _wt_rows ;;
    *)              _wt_goto "$cmd" ;;
  esac
}
