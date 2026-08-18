# ---------------------------------------------------------------------------- #
# core — output, small utilities, and the git questions worth asking
#
# Everything here takes the repo and the base ref as arguments. Nothing reads a
# profile. That is deliberate: these are the parts of the predecessor that were
# already repo-agnostic, and keeping them that way is what lets a nested repo
# with its own trunk reuse them unchanged.
# ---------------------------------------------------------------------------- #

_wt_err()  { print -u2 -P "%F{9}wt:%f $*" }
_wt_warn() { print -P "%F{11}wt:%f $*" }
_wt_info() { print -P "%F{8}·%f $*" }
_wt_ok()   { print -P "%F{10}✔%f $*" }
_wt_die()  { _wt_err "$*"; return 1 }
_wt_head() { print -P "%F{12}==>%f $*" }

# clip to $2 characters, marking the cut (zsh's printf pads by character, so a
# multibyte marker does not throw the column off)
_wt_fit() {
  local s=$1
  (( ${#s} > $2 )) && s="${s[1,$2 - 1]}…"
  print -r -- $s
}

# usable as a directory name and as a `wt <name>` word
_wt_slug() { print -r -- ${${1//\//-}//[^a-zA-Z0-9._-]/-} }

_wt_has_local()  { git -C "$1" show-ref --verify --quiet "refs/heads/$2" }
_wt_has_remote() { git -C "$1" show-ref --verify --quiet "refs/remotes/$2" }

_wt_gitdir() { git -C "$1" rev-parse --absolute-git-dir 2>/dev/null }

# the common gitdir — shared by every linked worktree, so its parent is the
# primary checkout no matter which worktree or subdirectory you stand in
_wt_common_root() {
  local d
  d=$(git -C "${1:-$PWD}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  print -r -- ${d:h}
}

# Is $2 checked out by a worktree of repo $1? prints the path if so
_wt_checked_out_in() {
  git -C "$1" worktree list --porcelain | awk -v b="refs/heads/$2" '
    /^worktree / { p = substr($0, 10) }
    $0 == "branch " b { print p; found = 1; exit }
    END { exit !found }
  '
}

# Tracked-file dirtiness. $3.. are extra pathspecs to ignore (a profile can name
# files an editor rewrites on its own, e.g. Obsidian's .obsidian/workspace.json).
_wt_dirty_count() {
  local repo=$1 n
  shift
  n=$(git -C "$repo" status --porcelain --untracked-files=no -- "$@" 2>/dev/null | wc -l)
  print -r -- ${n//[[:space:]]/}
}

# Untracked files that are not something we put there. There is no per-worktree
# .git/info/exclude — git only ever reads the shared one — so the tool has to
# carry its own notion of "I put this here" and subtract it.
_wt_stray_untracked() {
  local root=$1 f
  shift                       # remaining args: paths we seeded
  for f in ${(f)"$(git -C $root ls-files --others --exclude-standard 2>/dev/null)"}; do
    [[ -z $f ]] && continue
    [[ ${@[(Ie)${f%/}]} -gt 0 ]] && continue
    [[ -L $root/${f%/} ]] && continue
    print -r -- $f
  done
}

# How the branch stands to its remote counterpart, without touching the network:
#   ok    tracking a remote branch that still exists
#   gone  tracked one that has been deleted — which is what GitHub does when it
#         merges a PR, so the commit counts below stop meaning anything
#   none  never pushed, so the trunk is the honest comparison
_wt_upstream_state() {
  local repo=$1 branch=$2
  [[ -z $(git -C "$repo" config --get "branch.$branch.merge" 2>/dev/null) ]] &&
    { print -r -- none; return }
  git -C "$repo" rev-parse --verify --quiet "$branch@{upstream}" >/dev/null 2>&1 &&
    { print -r -- ok; return }
  print -r -- gone
}

# Would merging $2 into $3 change anything? Ancestry cannot answer that after a
# squash merge — the squash mints one new commit carrying the same tree, so the
# branch's own commits are never ancestors and any count reads "unmerged"
# forever. The merge *result* is the honest test: if it equals the trunk's tree
# there is nothing left to lose. Works offline and in repos that have no PRs.
_wt_contained() {
  local repo=$1 branch=$2 base=$3 merged tree
  git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || return 1
  merged=$(git -C "$repo" merge-tree --write-tree "$base" "$branch" 2>/dev/null) || return 1
  tree=$(git -C "$repo" rev-parse "$base^{tree}" 2>/dev/null) || return 1
  [[ -n $merged && $merged == $tree ]]
}

# Is every hunk the branch added already present in the trunk? This answers what
# _wt_contained cannot once the branch is *stale*: the trunk can hold the
# branch's contribution AND newer edits on adjacent lines, and a merge conflicts
# on that region even though nothing is missing — which is exactly what a
# one-entry-per-line index or backlog file produces. Zero context tests the hunks
# alone, against a throwaway index so nothing is touched.
#
# Deliberately only used to allow removing a *worktree*, which loses no commits —
# never to authorise deleting a branch, where a false positive would lose work.
_wt_work_in_base() {
  local repo=$1 branch=$2 base=$3 mb idx rc
  mb=$(git -C "$repo" merge-base "$base" "$branch" 2>/dev/null) || return 1
  idx=$(mktemp "${TMPDIR:-/tmp}/wt-idx.XXXXXX") || return 1
  if ! GIT_INDEX_FILE=$idx git -C "$repo" read-tree "$base" 2>/dev/null; then
    rm -f "$idx"; return 1
  fi
  git -C "$repo" diff -U0 "$mb..$branch" |
    GIT_INDEX_FILE=$idx git -C "$repo" apply --unidiff-zero --reverse --check --cached - 2>/dev/null
  rc=$?
  rm -f "$idx"
  return $rc
}

# Commits that live only here: vs upstream when there is one, else vs the trunk.
# A non-zero count does NOT mean unmerged — check _wt_contained before believing it.
_wt_unpushed() {
  local repo=$1 branch=$2 base=$3 from
  [[ -z $branch || $branch == '(detached)' ]] && { print -r -- 0; return }
  if git -C "$repo" rev-parse --verify --quiet "$branch@{upstream}" >/dev/null 2>&1; then
    from="$branch@{upstream}"
  elif git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
    from=$base
  else
    print -r -- 0; return
  fi
  git -C "$repo" rev-list --count "$from..$branch" 2>/dev/null || print -r -- 0
}

_wt_behind() { git -C "$1" rev-list --count "HEAD..$2" 2>/dev/null || print -r -- 0 }

# The branch name, or — when HEAD is detached — what git is in the middle of.
# `rev-parse --abbrev-ref HEAD` just says "HEAD", which reads as a branch called
# HEAD in a listing and hides a half-finished rebase.
_wt_head_label() {
  local repo=$1 b g
  b=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -n $b && $b != HEAD ]] && { print -r -- $b; return }
  g=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)
  if [[ -e $g/rebase-merge || -e $g/rebase-apply ]]; then
    print -r -- rebasing
  elif [[ -e $g/MERGE_HEAD ]]; then
    print -r -- merging
  elif [[ -e $g/CHERRY_PICK_HEAD ]]; then
    print -r -- cherry-picking
  else
    print -r -- detached
  fi
}

_wt_mid_operation() { [[ $(_wt_head_label "$1") == (rebasing|merging|cherry-picking) ]] }

# MERGED / OPEN / CLOSED and the number, tab separated; empty when there is no PR
# or gh cannot answer. This is the only authoritative answer to "is this work in
# the trunk": a squash merge mints one new commit carrying the same tree, so the
# branch's own commits never become ancestors and no amount of counting will say so.
_wt_pr() {
  local repo=$1 branch=$2
  (( WT_PR )) || return 0
  (( $+commands[gh] )) || return 0
  (cd "$repo" && gh pr view "$branch" --json state,number -q '"\(.state)\t\(.number)"' 2>/dev/null)
}

# per-worktree metadata, kept in the worktree's gitdir so git prunes it with the
# worktree. `purs` reads these two files, which is what keeps the prompt generic.
_wt_mark() {
  local dir=$1 label=$2 branch=$3 gitdir
  gitdir=$(_wt_gitdir "$dir") || return
  [[ -d $gitdir ]] || return
  print -r -- "$branch" > "$gitdir/wt-pinned"
  print -r -- "$label"  > "$gitdir/wt-label"
}

_wt_pinned() {
  local gitdir=$(_wt_gitdir "$1")
  [[ -n $gitdir && -f $gitdir/wt-pinned ]] && print -r -- "$(<$gitdir/wt-pinned)"
}

# `direnv status` reports "Found RC allowed 0" when the .envrc in the current
# directory is approved, 1 when it is blocked
_wt_direnv_allowed() {
  [[ $(cd "$1" && direnv status 2>/dev/null | sed -n 's/^Found RC allowed //p') == 0 ]]
}

_wt_allow_direnv() {
  local dir=$1 rcdir
  (( $+commands[direnv] )) || return 0
  # Only ever mirror a decision that was already made: if the primary's .envrc
  # is not approved, approving a copy of it in a worktree would be the tool
  # granting a trust the user never did.
  [[ -e $WT_ROOT/.envrc ]] && ! _wt_direnv_allowed "$WT_ROOT" && return 0
  for rcdir in "$dir" "$dir"/*(/N) "$dir"/*/*(/N); do
    [[ -e $rcdir/.envrc ]] || continue
    # `direnv allow <path>` exits 0 and writes nothing when run from anywhere
    # else, so approve from inside the directory — and check, because a silent
    # no-op is indistinguishable from success by exit code alone
    ( cd "$rcdir" && direnv allow )
    _wt_direnv_allowed "$rcdir" ||
      _wt_warn "direnv still blocks $rcdir — run 'direnv allow' there"
  done
  return 0
}

# teach rupa/z about the new directory so `z` can find it too
_wt_register_z() { (( $+functions[_z] )) && _z --add "$1" 2>/dev/null; return 0 }
