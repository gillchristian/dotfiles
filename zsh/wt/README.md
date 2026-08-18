# wt — git worktrees, per repository

Git worktrees, driven per repository. Everything a single-repo predecessor
hardcoded for one checkout is now a per-repository profile. That predecessor is
retired; it survives only as `~/.zsh/attic/wt.zsh.retired-2026-08-18`.

```
~/.zsh/wt/wt.zsh              entry point, dispatch, usage
~/.zsh/wt/lib/core.zsh         output, git questions — no profile knowledge
~/.zsh/wt/lib/profile.zsh      registry, resolution, init, setup
~/.zsh/wt/lib/seed.zsh         seeding, companion repos, the fold policy
~/.zsh/wt/lib/cmds.zsh         the commands
~/.zsh/wt/completions/_wt
```

## Install

```zsh
source ~/.zsh/wt/wt.zsh
fpath=(~/.zsh/wt/completions $fpath)     # before compinit
```

The command is `wt`, every helper is `_wt_*`, and every runtime variable is
`WT_*`. It took that name on 2026-08-18, after earning it on three repositories.

## Two files

**The registry** — `~/.config/wt/repos`, one primary checkout per line. It exists
for the two things `$PWD` cannot answer: resolving a profile from outside any
checkout, and enumerating repos for the cross-repo picker.

**The profile** — `<primary>/.wt.zsh`, so it is versioned with the code it
describes. A repo that will not take the file falls back to
`~/.config/wt/profiles/<name>.zsh`. Either way it is read from the **primary**,
which always exists — that is what makes it safe for `wt new` to depend on,
before the worktree it is creating is there.

`wt help profile` is the reference. `wt init` writes a starting one by reading
the repo: trunk from `origin/HEAD`, ignored paths sorted into clone/link/skip,
companion repos found, ports sniffed out of `package.json`/vite/Go, the ticket
convention sampled from recent branch names. All guesses, meant to be edited.

## Adopting a repo

```zsh
cd ~/dev/thing
wt init          # writes .wt.zsh, registers the repo
$EDITOR .wt.zsh   # fix the guesses
wt setup         # make the primary satisfy the profile
wt doctor
```

`wt setup` is not optional and is the piece the predecessor never had. **Nothing in `.git/`
varies per worktree** — `info/exclude`, `core.hooksPath`, `refs/stash`, objects
and remotes are all shared, and a per-worktree `info/exclude` is *never read*. So
the entries that hide a companion repo and the symlinked config have to be
written once, in the primary, where they then apply everywhere. `setup` maintains
them in a marked block and `doctor` checks they are still there.

That same constraint is why the tool keeps its own list of what it put in a
worktree (`_wt_stray_untracked`) rather than asking git to ignore it locally.

Two details worth knowing, both learned the hard way:

- the trailing slash is load-bearing. A directory pattern never matches a
  symlink, so `nested:mirror` paths are excluded as `notes/` and linked paths as
  `shared` — `setup` gets this right per entry.
- `wt` never auto-discovers a repo. A profile is shell code (probes are
  commands), so it is only read for something you registered by hand or with
  `wt init`. Same bargain as direnv.

## What is per-profile

| | |
|---|---|
| `trunk` / `remote` | `master` here, `main` there; every comparison follows |
| `nested` | companion repos: `<path>:mirror[:fold\|require-merged\|ignore][:label]`, or `<path>:link` |
| `link` / `skip` / `seed_default` | the three dispositions for ignored paths |
| `ports` / `shared_note` / `label_dir` | labels for the scan; attribution is by cwd |
| `ticket` / `ticket_case` | how a branch name becomes a directory name |
| `wt_probe` | the repo's own `ls` badges — name, format, command |
| `gc_paths` / `post_new` / `add_filter` / `pr` | |

## Naming worktrees

Two independent questions: what the **branch** is called, and what the
**directory** is called.

A bare word is already both. `wt new login` creates the branch `login` and the
worktree `<home>/login` under every strategy — no ticket convention needed and
nothing to configure. `--as <name>` overrides the directory whenever you want
something else: `wt new feat/really-long-branch-name --as short`.

`naming=` decides what happens when the branch has slashes in it:

| `naming` | `feat/add-login` | `feat/ABC-12/x` | good for |
|---|---|---|---|
| `ticket` (default) | `feat-add-login` | `ABC-12` | ticket-per-branch repos |
| `last` | `add-login` | `x` | `<type>/<what>` conventions |
| `first` | `feat` | `feat` | `<person>/<what>` conventions |
| `slug` | `feat-add-login` | `feat-ABC-12-x` | short flat branch names |

`name_case=keep|upper|lower` applies to whatever the strategy extracted — so
`desk/desk-082-y-axis` can become `DESK-082` while `mono/item-library`, which
matched no ticket, is left alone rather than shouted at.

Anything these cannot express gets a function; the branch arrives on `$1`:

```zsh
wt_name() { print -r -- "${${1##*/}%%-*}" }   # feat/add-login -> add
```

`wt init` guesses the strategy from how branches are actually named in the repo
and prints what it picked. It reads live refs only, so a repo that deletes
branches after merging gives it a thin sample — check the line it writes.

One consequence worth knowing: `naming=ticket` is also what makes `wt new
ABC-12` search for an *existing* branch containing that ticket. Under the other
strategies a bare word is always a branch to create, which is the behaviour you
want when you are not using tickets at all.

Collisions are possible under `last` and `first` (`feat/x` and `fix/x` both want
`x`); the second one refuses with the `--as` hint rather than clobbering.

## Probes

The part that was a hardcoded migration count is now a command:

```zsh
wt_probe mig '%F{13}mig:{}%f' \
  'git diff --name-only --diff-filter=A $WT_BASE...HEAD -- db/migrations | wc -l'
```

Runs with cwd set to the worktree. Empty or `0` output means no badge; anything
else replaces `{}`. `$WT_TRUNK $WT_BASE $WT_ROOT $WT_NAME $WT_BRANCH
$WT_PATH` are available. Debug one with `wt probe [probe] [name]`, which
shows the command and its raw output.

Cost: one shell-out per worktree per probe on every `wt ls`, on top of the ~6
git calls a row already costs. Keep them cheap.

## Kept from the predecessor, deliberately

`_wt_contained` and `_wt_work_in_base` — the squash-merge reasoning. A squash
merge mints one new commit carrying the same tree, so the branch's own commits
never become ancestors of the trunk and `rev-list --count` reads "unpushed"
forever. The merge *result* is the honest test. The strict test authorises
deleting a branch; the lenient hunk-reversal test only authorises removing a
worktree, where a false positive loses nothing.

## zsh traps this hit, recorded so they are not re-introduced

Four of these were real bugs found while exercising the tool, not theory:

- **`local path=…` destroys `$PATH`** for the length of the call — `path` is the
  array tied to it. Everything after the declaration fails with "command not
  found: git". Any variable named `path`, `cdpath`, `fpath`, `manpath`, `psvar`
  or `module_path` is the same trap.
- **`local a=$1 b=$a` reads the *caller's* `a`**, not the one being declared in
  the same statement. Split the declaration. This one silently pointed a
  companion symlink at the wrong file and only showed up because the caller's
  loop variable happened to hold a stale value.
- **A bare `local x` on a name that is already local prints `x=value`** instead
  of redeclaring it. Inside a loop that leaks to stdout on the second iteration.
  Declare once at the top of the function.
- **`${arr:-a b c}` is one word**, not three — zsh does not word-split. The
  `protected` default arrived as `"master main master"` and matched nothing, so
  `wt new master` was allowed through the wrong guard.
- `print -r -- "a\tb"` emits a literal backslash-t; `${(ps:\t:)}` splits on a
  real tab. Use `printf` when building tab-separated records.
- `[[:space:]]#` as a repetition needs `extended_glob` — and with it on, `${x%%#*}`
  needs the `#` escaped.

## Adopting the profile into the repo, later

If you start with an untracked `<primary>/.wt.zsh` (which `setup` excludes for you) and
later decide to commit it from a worktree, the primary's next fast-forward fails:

```
error: The following untracked working tree files would be overwritten by merge:
	.wt.zsh
```

Git refuses this **even when the content is byte-identical** — verified. Delete the
untracked copy in the primary and sync; the merge checks the tracked one back out. `wt
sync` quotes git's reason rather than only saying "would not fast-forward", so the message
points at the file.

## Known rough edges

- `gh pr merge` fails locally in a worktree layout (`'master' is already used by
  worktree at …`) after having merged server-side. That is `gh`, not `wt`; the
  PR is merged and `wt rm` reads the right state.
- `add_filter` only applies to the parent's `git worktree add`. A companion's
  "Preparing worktree" line goes to stderr and is left alone deliberately —
  filtering it would mean swallowing that repo's real errors too.
- The cross-repo picker (`wt` with no args, outside a registered repo) needs
  fzf and a tty, so it has only been verified down to the row-building step
  (`wt _rows`), not through fzf itself.
