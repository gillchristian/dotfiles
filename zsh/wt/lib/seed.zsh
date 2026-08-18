# ---------------------------------------------------------------------------- #
# seeding and companion repositories
#
# The tracked repo is cheap to check out; what costs is the ignored build state
# beside it. Every path git reports as ignored gets one of three dispositions,
# and deriving the list from `git status --ignored` each time is what keeps it
# correct as a repo grows new build directories:
#
#   link   config and data that must not diverge — symlinked to the primary
#   clone  build state — `cp -Rc`, an APFS clone: copy-on-write, so a large
#          worktree costs metadata and almost no disk, and cargo/webpack
#          fingerprints survive the path change so caches stay warm
#   skip   regenerated per task, or state that must NOT be shared (a live
#          SQLite file cloned into two worktrees is two divergent databases)
# ---------------------------------------------------------------------------- #

# path mode policy label, for each nested entry (tab separated)
_wt_nested_specs() {
  local spec
  local -a f
  for spec in $WT_NESTED; do
    f=(${(s.:.)spec})
    # printf, not print -r: the latter emits a literal backslash-t, which the
    # ${(ps:\t:)} split on the other end would never see as a separator
    printf '%s\t%s\t%s\t%s\n' \
      "${${f[1]}%/}" "${f[2]:-mirror}" "${f[3]:-require-merged}" "${f[4]:-${${f[1]%/}:t}}"
  done
}

# everything the tool itself puts inside a worktree — subtracted from the
# untracked listing, because git has no per-worktree exclude to tell it with
_wt_seeded_paths() {
  print -rl -- $WT_LINK
  local line
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line}); print -r -- $f[1]
  done
}

_wt_skip_seed() {
  local rel=$1 pat
  for pat in $WT_SKIP; do
    [[ $rel == ${~pat} ]] && return 0
    [[ $rel == ${~pat}/* ]] && return 0
  done
  return 1
}

_wt_link_one() {
  # Split, not `local dest=$1 rel=$2 src=$WT_ROOT/$rel`: in zsh the right-hand
  # sides of a single `local` are expanded against the CALLER's scope, so `src`
  # would be built from whatever `rel` the caller happened to be holding.
  local dest=$1 rel=$2
  local src=$WT_ROOT/$rel
  [[ -e $src ]] || return 1
  if [[ -e $dest/$rel && ! -L $dest/$rel ]]; then
    _wt_warn "$rel exists in the worktree, not linking"
    return 1
  fi
  [[ -L $dest/$rel ]] && rm -f "$dest/$rel"
  mkdir -p "${dest}/${rel:h}"
  ln -s "$src" "$dest/$rel"
}

_wt_seed() {
  # no_monitor keeps the parallel clones from spamming job notifications
  setopt local_options no_monitor no_notify
  local dest=$1 rel n_link=0 n_clone=0 start=$SECONDS

  for rel in $WT_LINK; do
    _wt_link_one "$dest" "$rel" && (( ++n_link ))
  done

  # nested repos in link mode are a symlink too, not a worktree
  local line
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == link ]] || continue
    _wt_link_one "$dest" "$f[1]" && (( ++n_link ))
  done

  local -a todo=()
  if [[ $WT_SEED_DEFAULT == clone ]]; then
    for rel in ${(f)"$(git -C $WT_ROOT status --porcelain --ignored=matching 2>/dev/null | sed -n 's/^!! //p')"}; do
      rel=${rel%/}
      [[ -z $rel ]] && continue
      _wt_skip_seed "$rel" && continue
      [[ ${WT_LINK[(Ie)$rel]} -gt 0 ]] && continue
      [[ -e $WT_ROOT/$rel ]] || continue
      [[ -e $dest/$rel ]] && continue
      todo+=$rel
    done
  fi

  # -c is an APFS clone: one syscall per file, copy-on-write, so this costs
  # metadata and almost no disk. The paths are independent, so clone them at
  # once instead of waiting on each in turn.
  (( ${#todo} > 3 )) && _wt_info "cloning ${#todo} ignored paths"
  for rel in $todo; do
    mkdir -p "${dest}/${rel:h}"
    { cp -Rc "$WT_ROOT/$rel" "$dest/$rel" 2>/dev/null ||
      cp -R  "$WT_ROOT/$rel" "$dest/$rel" 2>/dev/null } &
  done
  wait

  for rel in $todo; do
    if [[ -e $dest/$rel ]]; then
      (( ++n_clone ))
    else
      _wt_warn "could not seed $rel"
    fi
  done

  _wt_info "seeded: $n_clone cloned, $n_link linked ($((SECONDS - start))s)"
}

# Drop the symlinks so `git worktree remove` does not see them as untracked work
_wt_unseed() {
  local dest=$1 rel line
  local -a f
  for rel in $WT_LINK; do
    [[ -L $dest/$rel ]] && rm -f "$dest/$rel"
  done
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ -L $dest/$f[1] ]] && rm -f "$dest/$f[1]"
  done
  return 0
}

# ---------------------------------------------------------------------------- #
# mirrors
#
# A mirror is a companion repository that follows the parent branch-for-branch:
# work on `feat/X` in the code implies a `feat/X` in the docs beside it. Its
# trunk moves on its own schedule, so every containment question about it is
# asked against ITS base, never the parent's.
# ---------------------------------------------------------------------------- #

_wt_nested_base() {
  local repo=$1 remote trunk
  remote=$(_wt_detect_remote "$repo")
  trunk=$(_wt_detect_trunk "$repo" "$remote")
  if _wt_has_remote "$repo" "$remote/$trunk"; then
    print -r -- "$remote/$trunk"
  else
    print -r -- "$trunk"
  fi
}

_wt_mirror_add() {
  local dir=$1 branch=$2 npath=$3
  local src=$WT_ROOT/$npath base where
  base=$(_wt_nested_base "$src")

  git -C "$src" fetch --quiet $(_wt_detect_remote "$src") 2>/dev/null

  if where=$(_wt_checked_out_in "$src" "$branch"); then
    _wt_die "$npath branch $branch is checked out at $where"
    return 1
  fi

  if _wt_has_local "$src" "$branch"; then
    git -C "$src" worktree add "$dir/$npath" "$branch" >/dev/null || return 1
    _wt_info "$npath: existing branch $branch"
  elif _wt_has_remote "$src" "$(_wt_detect_remote "$src")/$branch"; then
    git -C "$src" worktree add --track -b "$branch" "$dir/$npath" \
        "$(_wt_detect_remote "$src")/$branch" >/dev/null || return 1
    _wt_info "$npath: tracking $branch"
  else
    git -C "$src" worktree add --no-track -b "$branch" "$dir/$npath" "$base" >/dev/null || return 1
    _wt_info "$npath: new branch $branch off $base"
  fi
}

_wt_nested_attach() {
  local dir=$1 branch=$2 line
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    _wt_mirror_add "$dir" "$branch" "$f[1]" || return 1
  done
  return 0
}

# `git worktree remove` on the parent would delete a nested worktree silently —
# it is an ignored path, so nothing blocks it — and leave a dangling
# registration behind in the companion repo. Order matters: nested first.
_wt_nested_detach() {
  local dir=$1 line
  local -a f
  for line in ${(f)"$(_wt_nested_specs)"}; do
    f=(${(@ps:\t:)line})
    [[ $f[2] == mirror ]] || continue
    [[ -d $dir/$f[1] ]] || continue
    git -C "$WT_ROOT/$f[1]" worktree remove --force "$dir/$f[1]" ||
      { _wt_die "could not remove the $f[1] worktree"; return 1 }
    _wt_info "$f[1] worktree removed"
  done
  return 0
}

# ---------------------------------------------------------------------------- #
# fold — the teardown policy for a mirror
#
# A mirror exists to hold work describing code that is not on the trunk yet.
# Once the PR is merged that reason is gone, so the honest move at teardown is
# to do the squash-merge rather than refuse to remove the worktree. Only ever
# reached for `:fold`; `:require-merged` refuses instead, `:ignore` says nothing.
# ---------------------------------------------------------------------------- #

# a commit-subject area from the directories the mirror touched
_wt_fold_area() {
  local repo=$1 branch=$2 base=$3
  # three dots: only what the mirror introduced since the merge base. Two dots
  # would also list what the trunk added meanwhile, so the area was never unique.
  local -a dirs=(${(f)"$(git -C $repo diff --name-only "$base...$branch" 2>/dev/null |
                          cut -d/ -f1 | sort -u)"})
  (( ${#dirs} == 1 )) && [[ -n $dirs[1] ]] && { print -r -- $dirs[1]; return }
  print -r -- docs
}

# Files a squash-merge would conflict on, without touching a thing: merge-tree
# --name-only prints the merged tree, then the conflicted paths, then commentary.
_wt_fold_conflicts() {
  local repo=$1 branch=$2 base=$3 line past_tree=0
  git -C "$repo" merge-tree --write-tree --name-only "$base" "$branch" 2>/dev/null |
    while IFS= read -r line; do
      (( past_tree )) || { past_tree=1; continue }
      [[ -z $line ]] && break
      print -r -- $line
    done
}

_wt_fold() {
  local npath=$1 branch=$2 prnum=$3 wtname=$4
  local repo=$WT_ROOT/$npath
  local remote=$(_wt_detect_remote "$repo")
  local base=$(_wt_nested_base "$repo")
  local trunk=${base#$remote/}
  local n area msg head out
  local -a conf

  n=$(_wt_unpushed "$repo" "$branch" "$base")
  (( n )) || return 0
  _wt_contained "$repo" "$branch" "$base" && return 0

  # the merge lands in the companion's primary checkout, so it has to be on its
  # trunk and clean
  if [[ $(_wt_head_label "$repo") != $trunk ]]; then
    _wt_err "primary $npath is on $(_wt_head_label "$repo"), not $trunk — cannot fold $branch in"
    return 1
  fi
  if (( $(_wt_dirty_count "$repo" $WT_DIRTY_IGNORE) )); then
    _wt_err "primary $npath has uncommitted changes — commit them, then retry"
    return 1
  fi

  head=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" fetch --quiet "$remote" 2>/dev/null
  git -C "$repo" merge --ff-only "$base" >/dev/null 2>&1

  area=$(_wt_fold_area "$repo" "$branch" "$base")
  msg="$area: $(_wt_name_for "$branch") (code merged"
  [[ -n $prnum ]] && msg+=", #$prnum"
  msg+=")"

  # Ask what would conflict before starting, so a doomed merge is never begun
  # and the report can name the files.
  conf=(${(f)"$(_wt_fold_conflicts "$repo" "$branch" "$base")"})
  conf=(${conf:#})
  if (( ${#conf} )); then
    _wt_err "folding $branch into $npath $trunk conflicts in:"
    print -rl -u2 -- ${conf/#/      }
    _wt_err "nothing was changed. To finish by hand:"
    print -rl -u2 -- \
      "      git -C $repo merge --squash $branch" \
      "      # resolve, git add, then:" \
      "      git -C $repo commit -m ${(qq)msg} && git -C $repo push $remote $trunk" \
      "      wt rm ${wtname:-<name>}"
    return 1
  fi

  # A conflicted squash merge has no MERGE_HEAD, so `merge --abort` cannot undo
  # it — reset to the commit we started from.
  if ! out=$(git -C "$repo" merge --squash "$branch" 2>&1); then
    git -C "$repo" reset --hard --quiet "$head"
    _wt_err "the $npath squash-merge failed — nothing was changed. git said:"
    print -rl -u2 -- ${${(f)out}[1,5]/#/      }
    return 1
  fi
  if git -C "$repo" diff --cached --quiet; then
    git -C "$repo" reset --quiet --hard "$head"
    return 0                                    # the merge was a no-op
  fi

  if ! git -C "$repo" commit --quiet -m "$msg"; then
    git -C "$repo" reset --hard --quiet "$head"
    _wt_err "the $npath commit failed — nothing was changed"
    return 1
  fi
  _wt_ok "$npath: folded $n commit(s) into $trunk — $(git -C "$repo" log --oneline -1)"

  if git -C "$repo" push --quiet "$remote" "$trunk" 2>/dev/null; then
    _wt_info "$npath: pushed to $remote"
  else
    _wt_warn "$npath: committed but not pushed — git -C $repo push $remote $trunk"
  fi
}
