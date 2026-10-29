# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_Nothing yet._

## [1.5.0] - 2026-10-28

> **Script-facing flags.** `status --quiet` stops failing on drift, so a
> `status && link --force` chain runs. `checkpoint --label` names a checkpoint, and
> `rollback --to <label>` goes back to it; `rollback --steps N` undoes the N most
> recent checkpoint windows. Both reach past the markers the no-arg form stops at,
> and step over what an earlier rollback already undid, so rollback becomes a
> multi-level undo. The no-arg form is unchanged. Two fields on `rollback-marker`
> are additive under ADR 0002 (addendum), and hapi 1.1.1 – 1.4.0 read a 1.5.0 trail
> as before. The design, and what was weighed instead, is
> [ADR 0007](docs/adr/0007-rollback-steps-and-to.md).

### Added

- **`hapi status --quiet`**: the rows print as before, and only the exit code
  changes. Drift exits 0. Exit 1 means an actual error: a manifest that will not
  resolve or parse, no `$HOME`, or a target that could not be checked (an `ERROR`
  row, counted on one stderr line). The default stays the assertion CI wants. This
  is Tier-2 of the archived `status` exit-code issue.
- **`hapi checkpoint --label <label>`** writes the marker with a `"label"` field.
  - A label is 1 to 64 characters from `A-Z a-z 0-9 . _ -`, not starting with `-`.
    Anything else is exit 2.
  - A plain `hapi checkpoint` is byte-identical to 1.4.0's.
- **`hapi rollback --to <label>`** reverses everything after the most recent marker
  with that label, past any other checkpoints.
  - An unknown label is exit 1, with nothing changed.
  - If the checkpoint is already reached, or lies inside a range an earlier
    rollback went past, there is nothing to roll back: exit 0.
- **`hapi rollback --steps N`** undoes the N most recent checkpoint windows that are
  still in effect.
  - A window runs from one marker to the next. Back-to-back checkpoints are one
    step, and a window a rollback emptied is none, so repeating `--steps 1` steps
    back one window at a time.
  - Asking for more steps than the trail holds is exit 1, with nothing changed and
    the number available named.
  - `--steps` takes 1 to 999999999; it cannot be combined with `--to` (exit 2).
- Both forms print one line first naming where they go, such as
  ``rolling back to checkpoint `pre-deploy` on line 41 (<ts>)``. Then come the same
  reversal lines as the no-arg form.
- **Rollback's closing marker records `"from"`**: the trail line its range began
  on. That is how `--steps` and `--to` tell the end of an undo from a checkpoint, and
  step over the undo: its reversing entries and what they reversed are never
  touched again.
  - Every closing marker carries it, the no-arg form's included.
  - It is trusted only as digits naming a line before its own marker. Anything
    else makes the marker a checkpoint.
- **`--steps` and `--to` close a range with a marker even when nothing in it needed
  reversing**, so the next step moves on. The no-arg form keeps 1.1.1's rule: a
  marker only after a run that changed something.
- The trail reader records each entry's line, and the entries `label` and `from`.

### Security

P(-1) ran: 1.5.0 grows the trail format and lets rollback choose what it reverses.
The record is the *1.5.0 addendum* of
[`docs/audit/2026-10-28-audit.md`](docs/audit/2026-10-28-audit.md). No defect was
found.

- **F-063 [LOW] — accepted.** A hapi write that runs while a rollback runs can land
  inside the range the rollback closes, and later `--steps` / `--to` step over it.
  It was reproduced against a 1,500-link rollback.
  - It fails safe: the link stays, and `hapi unlink` still finds it.
  - The no-arg form has hidden such an entry the same way since 1.1.1.
  - Closing it would mean marking every entry rollback writes (ADR 0007).
- **Hardening:** `--steps` names its boundary marker from the trail. It prints a
  label or `ts` only in a shape hapi writes, so a hand-edited trail cannot send
  escape sequences to the terminal.
- **Every new guard is held by a test that a seeded revert turns red:** 38 of 38.
  1.2.0's 15, 1.3.0's 26 and 1.4.0's 19 are still caught.
  - The first run left four reverts green, and the pass closed each one.
  - One was a rule unpinned since 1.1.1: an errored rollback writes no closing
    marker. It is now tested in both forms.
  - One was a redundant check, now removed.

### Tests

- `tests/hapi.tcyr` 1,035 → **1,340** assertions (134 → 142 groups). A new tier
  covers:
  - `status --quiet`: drift, clean, an `ERROR` row, a bad manifest, no package;
  - `checkpoint --label`, and the label rule at its edges;
  - `--steps`: one window at a time, several at once, back-to-back checkpoints,
    more steps than exist, after the no-arg form, a window needing no reversal, and
    a 1.4.0-style closing marker;
  - `from`'s validation, eleven ways;
  - `--to`: across an earlier rollback without replaying it, a label used twice,
    an unknown one, one inside a rolled-back range, and F-061's take-back;
  - an errored run not sealed, in both forms;
  - unprintable label and `ts` bytes kept off the terminal;
  - every new flag accepted on its verb and refused on the other nine, with each
    usage error's exact message.
- `tests/agnos.tcyr` 67 → **77** (10 → 11 groups): `checkpoint --label`,
  `rollback --to` and `--steps` with the scope at `/`, under mirshi too.
- Verified:
  - x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds;
  - `cyrius lint` 0 warnings;
  - `cyrius test` and `cyrius test --aarch64`;
  - `cyrius fuzz` and `cyrius bench`;
  - `scripts/concurrency-test.sh`;
  - `scripts/agnos-smoke.sh` under mirshi, all five checks;
  - `cyrius deps --verify` 114 / 114.

  The 819-line golden against 1.4.0: 695 cases identical, 45 the version line, 74
  the usage text's new rows, 5 a closing marker's `from`. A model-checked
  differential fuzz of 50,000 lines against 1.4.0 found no mismatch. Lines without a
  new flag are byte-identical, and every refused line matches the model.

### Notes

- **`--steps 1` is not the no-arg form.** They differ in three cases:
  - right after a rollback, where the no-arg form finds nothing;
  - after back-to-back checkpoints;
  - over a window where nothing needed reversing, which only `--steps` / `--to`
    close with a marker.
- **A rollback from before 1.5.0** left a closing marker without `from`. `--steps`
  and `--to` read it as a checkpoint and replay its range, with no net change: run
  one more step.
- **Benchmarks:** flat to slightly faster against 1.4.0 (cold 131–134 vs 135–137 ms),
  trail byte-identical. `rollback --dry-run` over 1,500 links is flat at 50 ms. DCE
  binary 607,560 → 617,000 bytes.

## [1.4.0] - 2026-10-28

> **`created_dir` on `op:link`.** Through 1.3.0 the directories `link` made for a
> target were deliberately left behind (1.0.9, F-029). The trail recorded the symlink,
> not the directories, so any removal would have been an inference, and `rmdir` can
> take out a directory the user made on purpose. A link entry now records the
> directories its creation made, and `unlink`, `sync --prune` and `rollback` remove
> them with the link: exactly those, and only once empty. The field is additive under
> ADR 0002 (addendum); hapi 1.3.0 reads a 1.4.0 trail unchanged, and the other way
> round.

### Added

- **`"created_dir"` on `op:link`**: the outermost directory the link's creation made.
  Every directory from it down to the target's parent was made too, since `mkdir -p`
  makes a contiguous chain.
  - It is written last, and only when a directory was made. Every other entry is
    byte-identical to 1.3.0's.
  - It is one string, not a list: every value in the format is a string, and the
    1.0 – 1.3 reader treats anything else as a malformed line, after which it refuses
    to act on the trail at all.
  - A directory that was already there is never claimed. That includes one another
    row made a moment earlier, and, on Linux, one a racing process made (its EEXIST
    restarts the run).
  - On agnos, whose `mkdir` is idempotent, a new shim (`hapi_mkdir_made`) asks
    `stat` first.
- **`unlink`, `sync --prune` and `rollback` remove the directories hapi made**,
  deepest first:
  - They stop at the first directory that still holds something.
  - They never go above `created_dir`.
  - They act only after removing the link themselves: the link sitting in the
    directory is the proof the directory is still the one hapi made.
  - `unlink` and `--prune` remove the chains of everything the run removed together,
    so a directory one row made and another reused goes when the run removes both.
    `--prune` does this before its creates, so a row moved within a directory only it
    used re-makes the directory and owns it.
  - `rollback` works newest first, one entry at a time.
  - Each directory removed is reported as `  - <dir>/  (a directory hapi made)`.
  - A link already gone, a `--dry-run`, or an entry from before 1.4.0 removes no
    directory.
  - Rolling back an `unlink` re-makes the directories, and the replayed entry records
    them.
- **The F-018 take-back takes the directories with it.** When `link` (or rollback's
  re-link) cannot write the entry, it removes the directories it just made along with
  the link. If the symlink itself fails after its directories were made, they are
  removed too.
- A new `hapi_rmdir` shim (agnos `rmdir` takes a path length).

### Security

P(-1) ran: 1.4.0 changes the trail format and adds a removal path. The record is the
*1.4.0 addendum* of [`docs/audit/2026-10-28-audit.md`](docs/audit/2026-10-28-audit.md).

- **F-062 [MEDIUM] — never shipped.** The removal walk would have resolved through a
  made directory swapped for a symlink.
  - **The case:** the walk goes deepest first. With `.sw/new/deep` made by hapi, and
    `.sw/new` later replaced by a symlink to `/elsewhere`, `rmdir .sw/new/deep` was
    resolved through it and removed an empty `/elsewhere/deep`, a directory hapi never
    made. That is the F-015 / F-051 shape: a path judged on its spelling where the
    kernel acts on where it goes.
  - **Fix:** every directory from the link's parent up to `created_dir` must still be
    a real directory before any is removed.
  - **Found** by this pass before the release, and held by tests through both
    `unlink` and `rollback`.
- The four threat classes were walked across the new path:
  - `created_dir` must be a `/`-boundary prefix of its link's path, so an edited
    trail cannot point elsewhere;
  - `"/"` cannot qualify;
  - nothing is removed through a symlink;
  - a directory is removed only after its link is.

  Every guard is held by a test that a seeded revert turns red: 19 of 19, plus 1.3.0's
  26 still caught. One revert is equivalent and left out: collecting directories
  during `--dry-run`, where the link still in the directory means no `rmdir` can
  succeed.

### Tests

- `tests/hapi.tcyr` 970 → **1,035** assertions (130 → 134 groups). A new
  `created_dir` tier covers:
  - recording: the outermost directory, a reused directory, a pre-existing one, and
    the byte-identical line when nothing was made;
  - removal by `unlink`: shared directories, a user's file, a link already gone,
    `--dry-run`;
  - removal by rollback, including an empty pre-existing directory just above
    `created_dir` that must stay;
  - rolling back an `unlink`;
  - `--prune`, including the before-the-creates order;
  - a record that is not its link's own, including a same-length directory off its
    path;
  - F-062 through `unlink` and `rollback`;
  - the F-018 take-back's directories, and those a failed `symlink(2)` leaves (staged
    with a name over `NAME_MAX`).
- `tests/agnos.tcyr` 61 → **67** (9 → 10 groups): a link into new directories and its
  `unlink`, with the scope at `/`. This exercises both new shims' agnos arms, under
  mirshi too.
- Verified:
  - x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds;
  - `cyrius lint` 0 warnings;
  - `cyrius test` and `cyrius test --aarch64`;
  - `cyrius fuzz` and `cyrius bench`;
  - `scripts/concurrency-test.sh`;
  - `scripts/agnos-smoke.sh` under mirshi, all five checks;
  - `cyrius deps --verify` 114 / 114.

  The 819-line golden is identical to 1.3.0's but for the version line: its fixture's
  targets sit in existing directories, so no entry gains the field. Cross-version:
  1.3.0 lists, checks and unlinks a 1.4.0 trail correctly, and 1.4.0 leaves an
  unrecorded 1.3.0 link's directory alone.

### Notes

- **One gap, accepted.** A directory is removed only together with the link whose
  entry claimed it. If that row is removed in one run while another row still uses
  the directory, the directory stays, and it stays when the second row goes later,
  because that row never claimed it. It is left empty, as every directory was before
  1.4.0. Claiming it for the second row would mean `link` reading the trail on every
  run; that was weighed and not taken.
- **The directory removals are not written to the trail.** The `op:unlink` they
  follow is. Reversing it re-makes them, and the replayed `op:link` records them
  again.
- **Benchmarks:** flat to slightly faster against 1.3.0 (cold 133–134 vs 136–137 ms;
  the old directory walk called `mkdir` on the target's parent twice). Trail
  byte-identical. DCE binary 603,424 → 607,560 bytes.

## [1.3.0] - 2026-10-28

> **sync: no package, and `--prune`.** The two open dogfood issues, both on `sync`, and
> both additive. A recovery is now one command: `hapi sync` with no package syncs every
> package under `HAPI_PACKAGE_ROOTS`. A dropped manifest row is now one trail entry, not
> an 11-entry rotation: `hapi sync --prune` removes the links whose rows left the
> manifest. The design, and what was weighed instead, is
> [ADR 0006](docs/adr/0006-sync-package-roots-and-prune.md). The manifest schema (ADR
> 0001) and the audit-trail line shape (ADR 0002) are unchanged: neither form writes a
> new field.

### Added

- **`hapi sync` with no package** syncs every package under `HAPI_PACKAGE_ROOTS`.
  - The variable is colon-separated, and every entry must be absolute.
  - Each root is scanned one level deep for `<root>/<name>/hapi.cyml`. Dot-names and
    directories without a manifest are ignored.
  - The scan follows no symlink: a symlinked package directory or manifest is named in
    a note and skipped, so a root bounds exactly what gets linked.
  - Two packages sharing a name are both refused, because the trail could not tell
    their links apart.
  - Packages sync in name order, each exactly as `hapi sync <dir>` would. A failing
    one does not stop the rest, and `synced N / M packages` closes the run.
  - The trail is then read only to *name* packages it has live links for whose
    directory no root holds. They are not synced, because their scope cannot be known.
  - `HAPI_PACKAGE_ROOTS` grants nothing: every target is still bounded by the scope,
    `--root` and ADR 0005.
  - Unset, or a relative entry, is exit 2; a root that cannot be listed, or no package
    found, is exit 1.
  ([`docs/development/issues/archived/2026-05-24-no-arg-sync-bootstrap-recovery.md`](docs/development/issues/archived/2026-05-24-no-arg-sync-bootstrap-recovery.md))
- **`hapi sync [<pkg>] --prune`** also removes the links whose rows left the
  manifest, one `op:unlink` each (the entry `hapi unlink` writes, so `rollback`
  reverses it the same way).
  - **A link is a candidate when it is all of:** a live `op:link` under the manifest's
    name; with its source in *this* package directory; with its target in *this* run's
    scope; and with no row still in the manifest targeting it. So a same-named package
    elsewhere, or a `--root` run, is never pruned by another.
  - **A link that is no longer the one hapi wrote** refuses the whole package, and
    `--force` does not override that.
  - **The package is planned whole before any write.** The link half's refusals come
    first, then the prune half, then F-055's trail preflight, the removals, and the
    creates.
  - The dogfood case, one row of six dropped, writes 1 entry where the rotation wrote
    11, and the kept links are never touched.
  ([`docs/development/issues/archived/2026-05-20-sync-prune-deferred-row-removal-rotation.md`](docs/development/issues/archived/2026-05-20-sync-prune-deferred-row-removal-rotation.md))
- **`--force` on `sync`, with `--prune`.** Prune refuses past half of the package's
  live links, so an emptied or truncated manifest is caught; `--force` lifts that limit
  **and nothing else**. `sync` still never overwrites a conflict (that is
  `link --force`), and `sync --force` without `--prune` is exit 2.

### Changed

- **`hapi --help`** shows the new `sync` forms. The `sync` line became five lines; the
  rest of the text is unchanged.
- **`hapi sync` with no package** was usage, exit 2. It is still exit 2 when
  `HAPI_PACKAGE_ROOTS` is unset, now with a message naming the variable.
- **`hapi sync --force`** was "unexpected flag", exit 2. It is still exit 2 without
  `--prune`, now saying what `--force` means on `sync`.
- **Internal:** `cmd_link` is split into `_hlnk_plan_run` (parse, plan, every refusal,
  no write) and `_hlnk_execute`, so that `sync --prune` can plan both halves before
  writing either. Behaviour is identical: the 819-line golden, run on 1.2.1 and on the
  split alone, is byte-identical.

### Security

P(-1) re-ran: no-arg sync turns a directory walk into write targets, and prune removes
links. The record is the *1.3.0 addendum* of
[`docs/audit/2026-10-28-audit.md`](docs/audit/2026-10-28-audit.md). It walked the four
threat classes and found one defect, on the removal path prune shares with `unlink`.

- **F-061 [MEDIUM] — a removal whose trail entry could not be written stayed removed.**
  F-055 (1.1.1) made `unlink` prove the trail writable before it removes anything. But
  an append can still fail after that pre-flight passed: a full disk, or a file-size
  limit. Staged with `ulimit -f` on 1.2.1, `hapi unlink p` deleted both of the
  package's links, recorded neither, and reported `unlinked 0 / 2`. The trail went on
  calling them live.
  - **`unlink`, `sync --prune` and rollback's link reversal** now put the link back,
    with the text it had.
  - **Rollback's unlink reversal** removes the link it just re-created.
  - All of them stop the run there, with `audit-trail write failed for <target>` and
    whether the change was taken back. This mirrors what `link` has done for its own
    links since F-018.
  - **An `adopt` reversal**, three steps, is not taken back but reported exactly.
  - Forward `adopt` already said "adopt succeeded but audit-trail write failed", and
    is unchanged.

Every guard above, and F-061's take-back, is held by a test that a seeded revert turns
red: 26 of 26, including two F-055 pre-flight reverts. The take-back would otherwise
hide those on disk, so their tests now also assert which path refused.

### Tests

- `tests/hapi.tcyr` 826 → **970** assertions (121 → 130 groups). Eight new groups cover:
  - the dogfood prune, the limit, and ownership (a replaced link refuses even with
    `--force`);
  - scoping by package directory and by scope;
  - the trail guards (a torn tail, a corrupt interior);
  - the scan: two roots, dot-dirs, a symlinked package, a failing package mid-run,
    no-arg `--prune`, twins, and every configuration refusal;
  - the CLI, including the trail note;
  - F-061 on every path: link, unlink, prune, and rollback's link, unlink and adopt
    reversals. These are driven by a new test hook, `audit_test_fail_appends`, which
    fails the append while the pre-flight still passes; that is the window, and a
    `.tcyr` cannot open it with an rlimit without raw syscalls. The hook also gives
    `link`'s F-018 take-back its first test.

  The flag matrix gains `--prune`, accepted on `sync` only, and `sync`'s `--force`.
- `tests/agnos.tcyr` 55 → **61** (8 → 9 groups): a scan and a prune with the scope at
  `/`, which runs on agnos under mirshi too. The scan's directory listing and prune's
  unlink both have agnos arms.
- Verified:
  - x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds;
  - `cyrius lint` 0 warnings;
  - `cyrius test` and `cyrius test --aarch64`;
  - `cyrius fuzz` and `cyrius bench`;
  - `scripts/concurrency-test.sh`;
  - `scripts/agnos-smoke.sh` under mirshi, all five checks;
  - `cyrius deps --verify` 114 / 114.

  The 1.2.1 golden diffs only in the usage text, the version line, and the two `sync`
  forms above.

### Notes

- **Benchmarks:** per-package `sync` is flat against 1.2.1, with a byte-identical
  trail. One no-arg `hapi sync` over the harness's 100 packages takes 80–84 ms cold and
  63–67 ms warm, where the 100-process loop it replaces takes ~133 / ~109, and it writes
  the same trail byte for byte. The DCE binary went 580,928 → 603,424 bytes. See
  `docs/benchmarks.md`.
- **One root, one scope.** The packages under a root are synced into the run's scope,
  so keep `--root` packages under a root of their own.
- A package synced through a different spelling of its directory (a symlinked path)
  does not recognise its earlier links, so `--prune` leaves them. That is an under-prune,
  which fails safe, and `hapi unlink` still removes them.

## [1.2.1] - 2026-10-28

> **cmdit fallout.** A patch on 1.2.0's migration, with no new surface and no change in
> what hapi prints or does. A model-checked differential fuzz of 50,000 command lines
> against 1.1.1 found no behavioural fallout. It did find one precedence shift that
> 1.2.0's notes left out (below). The two fixes are structural: commands no longer depend
> on the command line, and each verb's parse is finished the way cmdit finishes it.

### Fixed

- **Including one command pulled in the whole command line.** 1.2.0 put the dispatcher
  in `src/cli.cyr`, which also held the `--dry-run` flag that five commands include. So
  any unit that included a command pulled in every verb and the dispatcher through an
  include cycle. `tests/agnos.tcyr` includes `link`, `status` and `unlink`, so it got all
  of them. The flag now has its own leaf, `src/dry_run.cyr`, and the dispatcher depends
  on the commands, not the reverse. The agnos test build shrinks 1,329,328 → 1,282,816
  bytes. The rest of its growth over 1.1.1 (1,226,392) is cmdit itself, which `[deps]`
  prepends to every compile.
- **The verb's parse is finalized.** 1.2.0 parsed each verb with `cmdit_parse_argv` and
  skipped `cmdit_finalize`, the other half of `cmdit_parse_verb`, so a flag given
  `cmdit_env` or `cmdit_required` would have been silently ignored. hapi registers
  neither, so nothing observable changes; a later flag that does will work.

### Tests

- Unchanged at 826 + 55: neither fix changes behaviour a test can see. The evidence is
  instead:
  - **The 1.2.0 golden** (819 command lines) is identical on 1.2.1 and on the released
    1.2.0, but for the version line.
  - **A differential fuzz.** 50,000 random command lines across five seeds were drawn
    from every verb, flag, value and unknown-flag shape, leaving out 1.2.0's additive
    forms. They ran on 1.1.1 and 1.2.1, each checked against a model of its own
    semantics: 1.1.1's walk, and 1.2's parse, positional cap, `-` values and then
    grants. There were zero mismatches. Every line that runs produces byte-identical
    output and trees from both. The model is in the *1.2.0 addendum* of
    `docs/audit/2026-10-28-audit.md`.
- Verified: x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds (the DCE binary is
  unchanged at 580,928 bytes); `cyrius lint` 0 warnings; `cyrius test` and
  `cyrius test --aarch64`; `cyrius fuzz` and `cyrius bench`;
  `scripts/concurrency-test.sh`; `scripts/agnos-smoke.sh` under mirshi, all five checks;
  `cyrius deps --verify` 114 / 114.

### Notes

- **Correction to 1.2.0's precedence list.** It named two shifts on lines with more
  than one error: a flag error before an extra positional, and a usage error before a
  `--root` denial. There is a third. An empty `--root` (exit 2) is reported after a flag
  error or an extra positional anywhere on the line, where 1.1.1 reported whichever came
  first. Among the `--root` values it is still judged in order with the grants. Exit 2
  either way.
- `docs/development/state.md` listed per-component symlink resolution in `src/cap.cyr`
  as work still to do. It shipped in 1.0.8 (F-002 / F-015), and 1.1.1 decided the
  `--root` grant on the resolved root (F-051).
- No benchmark row: nothing on the `sync` path changed.

## [1.2.0] - 2026-10-28

> **Adopting cmdit.** `src/main.cyr`'s hand-rolled argv walk is replaced by
> [cmdit](https://github.com/MacCracken/cmdit) 1.5.0, and the dispatcher moved to
> `src/cli.cyr`, where `tests/hapi.tcyr` drives it with a synthetic argv. The v1.0
> command surface is frozen, so everything that changes is additive. Before any code
> changed, a golden of 819 command lines was captured from the 1.1.1 binary: every
> verb × every flag, value and positional shape, plus the top-level forms. 1.2.0 diffs
> clean against it except for the forms listed below and one fix (F-060). The manifest
> schema (ADR 0001) and the audit-trail line shape (ADR 0002) are unchanged, and a
> `sync` writes a byte-identical trail.

### Added

- **`hapi <verb> --help` / `-h` and `--version` / `-v`.** They print the usage or
  `hapi <version>` and exit 0, as at the top level; through 1.1.1 each was an
  unexpected flag (exit 2). `--help` answers past extra positionals but not past a bad
  flag: `hapi link --help --bogus` names `--bogus`, exit 2.
- **`--root=PATH` and `--backup-to=DIR`**, beside the separate spelling. `--root=PATH`
  is granted exactly as `--root PATH`. A value starting with `-` is refused in either
  spelling (`--root=-x`, `--root=--dry-run`); write `./-name`, as the message says.
- **`--` ends a verb's flags.** What follows is positional, so `hapi link -- -pkg` takes
  `-pkg` as the package: an alternative to the `./-name` advice. Before the verb it is
  still an unknown command (`hapi -- link pkg`, exit 2), because the command is
  `argv[1]` alone.
- **A lone `-` is a positional**, as in getopt, not an unexpected flag. hapi gives it no
  stdin meaning: `hapi inspect -` reads `./-/hapi.cyml`. As a `--root` or `--backup-to`
  value it is still refused.

### Changed

- **Argument parsing is cmdit's** (`[deps.cmdit]`, tag 1.5.0, commit-pinned in
  `cyrius.lock`). Each verb parses on its own cmdit handle that registers only that
  verb's flags. A flag another verb takes is still refused with exit 2
  (`guides/dry-run.md`, `backup-to.md`, `capability.md`), and every message is the
  1.1.1 text: hapi renders cmdit's errors itself, naming the token as typed through
  `cmdit_err_token` (``unexpected flag for `link`: --x``). `--root` and `--backup-to`
  carry `cmdit_reject_flag_value`. `main()` no longer calls `args_init()`;
  `cmdit_argv` reads the command line, once. The usage text stays hand-written, because
  `cmdit_help_fd` cannot reproduce it byte for byte.
- **Which error a line reports, when it has more than one.** cmdit parses the whole
  line before hapi checks positional counts and grants. A flag error (an unknown flag,
  a missing value) is reported before an extra positional: `hapi link a extra --bogus`
  names `--bogus`, where 1.1.1 named `extra`. Any usage error (exit 2) is reported
  before a `--root` denial (exit 1): `hapi link pkg --root /etc --bogus` exits 2, where
  1.1.1 exited 1. An empty `--root` keeps its 1.1.1 place among the grants.
- **Unchanged on purpose**, each held by the golden and a test. `hapi --version
  anything` still prints the version, and `hapi --help anything` the usage, at exit 0.
  Nothing is accepted before the verb (`hapi --dry-run link pkg` is an unknown command).
  Every `--root` given must be granted, so a denied one is not rescued by a later one.
  `-V` stays unknown; hapi's version letter is `-v`.

### Fixed

- **F-060 [LOW] — an empty `--root` wrote a stray NUL to stderr.** `hapi link pkg
  --root ''` printed its message and then the literal's NUL terminator. Its `eprint`
  length was hand-counted one byte long, the one F-019's sweep (1.0.9) missed. Every
  message helper in `src/cli.cyr` is `strlen`-based now.

### Security

P(-1) re-ran on the argument surface, which is a path-argument surface. The record is
the *1.2.0 addendum* of
[`docs/audit/2026-10-28-audit.md`](docs/audit/2026-10-28-audit.md).

- **F-013 (extra positionals) holds.** Each verb's slot count (1; 2 for `adopt`; 0
  for `rollback`, `checkpoint` and `list`) is `cmdit_require_positionals_max`.
  `hapi rollback <pkg>` is refused and the trail is untouched.
- **F-019 (flag-shaped values) holds, and is wider.** `cmdit_reject_flag_value`
  refuses a flag-shaped separate value during the parse, where 1.1.1's walk refused it,
  so a `--bogus` after it is never reached. hapi also refuses a lone `-`, which cmdit
  would take as a value, and every attached value starting with `-`.
- **F-033 (`inspect` flags exit 2) holds.** `inspect` registers no flags.
- **F-051 (the `--root` grant) holds.** `cap_check_root_r` runs on every `--root`
  value, in order, after the parse and the positional check, on the value the run uses.
- New: F-060, above.

Each holds under a seeded revert: 15 reverts of `src/cli.cyr`, each turning the suite
red.

### Tests

- `tests/hapi.tcyr` 469 → **826** assertions (112 → 121 groups). A new `cli` tier
  drives `hapi_cli_run` with a synthetic argv and captures stdout and stderr through
  `dup2`, so messages are asserted byte for byte. It covers the top-level forms, every
  verb × every flag (50 probes), F-013 on all ten verbs, F-019 in nine spellings,
  F-051, F-060, the additive forms, and each flag reaching its command.
  `tests/agnos.tcyr` is unchanged at 55. Both pass on x86_64 and on aarch64 under qemu.
- Verified: x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds; `cyrius lint`
  0 warnings across `src/` and `tests/`; `cyrius fuzz` and `cyrius bench`;
  `scripts/concurrency-test.sh`; `scripts/agnos-smoke.sh` under mirshi, all five
  checks, with checks 1 and 4 (`--version`, an unknown verb exits 2) unmodified;
  `cyrius deps --verify` 114 / 114.

### Notes

- **Benchmarks: flat.** An interleaved A/B against 1.1.1 over five pairs measured
  cold 131–133 vs 132–135 ms, warm 108–110 vs 107–109, and 100 single-package syncs
  113–116 vs 115–117. The trail is byte-identical and warm growth is 0. The DCE binary
  went 552,488 → 580,928 bytes, all but 4 KB of it code: cmdit, unlike 1.1.0's bayan
  tables. See `docs/benchmarks.md`.
- **The dispatcher hands cmdit `argv[1]` alone**, not the whole line. A full
  `cmdit_dispatch` would have broken three 1.1.1 answers: `hapi --version x` (exit 0)
  would be an unknown command, `hapi --version --help` would print help, and `hapi --
  link pkg` would run `link`. The verb's handle parses `argv[1..]` with
  `cmdit_parse_argv`, which is what `cmdit_parse_verb` would hand it, since hapi has no
  global flags.
- **`--root` and `--backup-to` are registered with `cmdit_repeat`**, not `cmdit_str`,
  so that every occurrence is checked as 1.1.1's walk checked it. The value in effect is
  still the last.
- New verbs append to the `HapiVerb` enum and the `cmdit_verb` order in `src/cli.cyr`:
  cmdit numbers verbs by registration.

## [1.1.1] - 2026-10-28

> **The P(-1) audit and its repairs.** One pass over the 1.1.0 tree, filed as
> [`docs/audit/2026-10-28-audit.md`](docs/audit/2026-10-28-audit.md): findings
> F-035 – F-059, every repair landing here, each with a test that fails against the
> unfixed code. The pass found the capability boundary open again. 1.0.8 decided
> containment on the resolved path, but only for the scope, only at plan time, and
> with `..` collapsed before symlinks were followed. Four HIGH findings came out of
> that, one of which (`link --force` deleting a row's own source) loses data. Command
> surface, manifest schema (ADR 0001) and audit-trail line shape (ADR 0002) are
> unchanged; ADRs 0001, 0002, 0003 and 0005 gain clarifying addenda.

### Security

- **F-045 [HIGH] — `link --force` deleted the package's own file.** With
  `~/.ssh -> dotfiles/pkg/ssh`, the row `ssh/config -> .ssh/config` names its source
  as its target. `link` called it an existing regular file, and `--force` deleted the
  only copy and planted a symlink to itself (`linked 1 / 1`, exit 0). `adopt
  ~/.ssh/config` moved the package's file to a second name and left a dangling link
  inside the package. A target that resolves into the package is now refused by
  `link` and `adopt`; `--force` does not override it.
- **F-051 [HIGH] — `--root` through a symlink escaped `$HOME` with no grant.**
  `--root ~/trap` with `trap -> /outside` passed on its spelling, after which every
  check resolved both sides through `trap` and agreed. `link` wrote into `/outside`,
  and `--force` deleted a file there. The grant is now decided on the resolved root,
  against the resolved `$HOME` and resolved `HAPI_ALLOWED_ROOTS` entries.
- **F-052 [HIGH] — `..` was collapsed before the symlink in front of it was
  followed.** `adopt 'a/../c.conf'` with `a -> /outside/deep` moved `/outside/c.conf`
  into the package. The resolver now walks `.` and `..` against the resolved prefix,
  as the kernel does, and `adopt` refuses a `..` component outright.
- **F-054 [HIGH] — `adopt` of a granted path outside the scope root crashed or
  garbled the row.** The manifest target was sliced at the scope root's length
  without checking the prefix: SIGSEGV (exit 139) when the path was shorter, a
  truncated target in the manifest and the trail when longer. It is now refused, since
  a file outside the scope root has no relative target to record.
- **F-057 — a row beneath another row's target escaped at execute time.** Both were
  planned as absent; the outer row then planted a symlink to an outside directory and
  the inner row was written through it. Nested targets are now refused.
- **F-047 — `/` contained nothing.** `--root /` with `HAPI_ALLOWED_ROOTS=/` refused
  every row, and so did agnos's default `HOME=/`, for every verb.
- **F-042 — CI fetched the toolchain installer from cyrius's mutable `main`.** It now
  fetches `scripts/install.sh` from the pin's tag, to a file, then runs it.
- **F-039 — the agnos no-follow open is atomic.** It passes `O_NOFOLLOW` (bridged to
  `AO_NOFOLLOW`, kernel ≥ 1.56.53), closing F-031's residual race. The readlink
  pre-check stays for older kernels, which ignore the bit, and its buffer grew from 64
  to 4096 bytes. agnos readlink answers -1 for a link body that does not fit, so any
  link body of 65 bytes or more had been followed. A real kernel shows this; mirshi
  does not.

### Fixed

- **F-046 — links under a symlinked parent dangled while `status` said OK.** The link
  text was computed from the spelled parent. It now comes from the directory the link
  physically sits in; the text is byte-identical whenever no parent is a symlink.
  Links 1.1.0 wrote there stay removable by `unlink` / `rollback`; `link` reports them
  as a conflict.
- **F-053 — a `./` target produced a dangling link, reported OK.** Fixed by F-046 for
  manifest targets; `adopt` now normalizes `.` and `//` in its `<file>` argument.
- **F-055 — `unlink`, `rollback` and `adopt` mutated before proving the trail
  writable.** With a torn tail, `unlink` removed every symlink and recorded none. All
  three now run `link`'s preflight first.
- **F-056 — `rollback` doubled the trail every run.** With no marker, each run
  re-reversed the previous one's entries (1, 2, 4 … 512). A clean rollback that
  changed something now closes its window with a `rollback-marker`; a second run
  does nothing, as the guide always said.
- **F-038 — `rollback` called a failed manifest rewrite "row not found" and exited
  0.** The row stayed, with its source just moved out of the package. Only a missing
  row is a warning now; any other failure names its reason and exits 1. The writer
  reports a leftover `hapi.cyml.<pid>.tmp` as such, `adopt` prints the writer's
  reason, and `check` lists leftovers on a `note:` line.
- **F-037 — `check` passed a package directory it could not list.** A mode-0311
  directory checked clean with an orphan in it. A failed listing is now an error.
- **F-048 — `check` let through a row source that runs through a regular file
  (`f/sub`).** `link` refused that row and pointed the user to `check`. `check` now
  uses the same predicate as `link` and `status`.
- **F-049 — `link_probe` hung on a FIFO and misread unreadable directories.** A FIFO
  at a target hung `link`, `status` and `--dry-run`. A mode-000 or mode-0300
  directory read as a file, so `adopt` moved a whole directory tree into the package.
  It is now classified with `stat`.
- **F-058 — a symlinked `hapi.cyml` was replaced by a private copy.** The atomic
  rewrite renamed over the link. The writer and `adopt` now refuse it.
- **F-041 — appending to a CRLF manifest wrote LF lines.** The row now matches the
  file's ending. The remove's blank-line trim now handles CR, so CRLF manifests get
  the same tidy-up LF ones do.
- **F-044 — on agnos, an absent audit trail was refused as unreadable.** `list`,
  `unlink` and `rollback` failed on a first run. "Absent" is now decided by stat
  there.
- **F-050 — on agnos, every stat failure read as "absent".** A path through a regular
  file now probes as an error, as it does on Linux.
- The trail append refuses when its lock fails instead of writing unlocked. On agnos
  the lock is what makes the append atomic. (Hardening; not constructed.)

### Changed

- **Rollback appends a marker** after a clean run that changed something (F-056).
  This is additive, and is the same entry `checkpoint` writes.
- **The CI agnos step runs for real (F-043).** `scripts/build-mirshi.sh` builds mirshi
  at a pinned tag with hapi's own toolchain pin. A new target-neutral
  `tests/agnos.tcyr` exercises every agnos-conditional path. The smoke step runs that
  suite under mirshi and fails on any non-zero exit, SKIP included.
- `hapi check` prints a `note:` line for each staging leftover; the exit code is
  unchanged.
- Error text: `adopt` says why a manifest edit failed. New refusals: target in the
  package, nested target, `..` in an adopt path, adopt outside the scope root, and a
  symlinked `hapi.cyml`.

### Tests

- `tests/hapi.tcyr` 387 → **469** assertions (95 → 112 groups). The new `1.1.1`
  section covers every repair above; each test was run against the reverted code and
  fails there (F-049's hangs instead; confirmed with a timeout). The harness routes
  `symlink` / `unlink` / `mkdir` through hapi's shims, so it compiles for agnos.
- **New `tests/agnos.tcyr`, 55 assertions in 8 groups.** It is target-neutral and
  passes on x86_64, on aarch64 under qemu, and on agnos under mirshi. It includes a
  full `link` / `status` / `unlink` round trip with the scope at `/`.

### Notes

- Retroactive ids: **F-035** is 1.0.12's aarch64 `O_NOFOLLOW` literal and x86-only
  harness; **F-036** is 1.1.0's `---` writer fixes.
- **F-059 is accepted, not fixed: `adopt` cannot succeed on a real agnos kernel.** The
  kernel's ext2 rename refuses an existing destination, and its flock refuses a
  directory fd. It fails closed. See
  [`docs/development/issues/2026-10-28-adopt-on-agnos-kernel.md`](docs/development/issues/2026-10-28-adopt-on-agnos-kernel.md).
- **mirshi differs from the agnos kernel on four calls** (the audit's *Harness gap*),
  so CI's agnos run cannot see F-059 or the long-link half of F-039.
- Benchmarks: +6 % cold / +7 % warm against 1.1.0, from the extra per-row resolution.
  The trail is byte-identical and warm growth is 0.

## [1.1.0] - 2026-10-28

> **The cyrius 6.7 line.** Pin `6.6.20` → `6.7.18`. The code compiled cleanly on all
> four builds and the existing suite passed unchanged, but the bump moved one rule
> underneath hapi without telling it. bayan, the CYML parser, changed where a manifest's
> header ends, and hapi's own manifest writer did not follow. That is fixed here and
> pinned by tests, so the next drift fails the suite instead of shipping. Command
> surface, manifest schema (ADR 0001) and audit-trail format (ADR 0002) are unchanged.

### Fixed

- **`adopt` could record a row nothing would ever read.** hapi parses only the CYML
  header, above the first `---` line. 6.7.18's bayan (1.11.1, from 1.5.12) widened what
  counts as that line: a `---` ending in CR LF, and a final `---` with no newline after
  it, are now delimiters. `_hmw_find_separator` in `src/manifest_write.cyr` still knew
  only `---\n`. On those manifests it found no delimiter and appended at end of file,
  **below** the delimiter the reader now sees, so the row landed in the body. `adopt`
  would then move the file into the package, plant the symlink and write the trail
  entry, while the manifest row recording it was invisible: F-028's orphan shape,
  reached by a toolchain bump. The writer now uses bayan's rule byte for byte
  (`_hmw_delim_at`), and append inserts above the delimiter on every line ending. This
  never shipped: it existed only between the pin bump and this fix.
- **`manifest_remove_link_row` could delete the package's documentation.** It searched
  the whole file, so a `[[link]]` written as an *example* in the markdown body matched,
  was cut out, and remove reported success, while the real header row (if any) stayed
  and the reader saw no change. Remove now searches only the header. This bug is older
  than the bump and affected LF manifests too. Its trigger is `rollback` of an `adopt`
  whose row exists only as a body example.

### Changed

- **Toolchain `6.6.20` → `6.7.18`.** `lib/` resynced to the 6.7.18 full snapshot
  (`cyrius lib sync --full`, 113 files; same file set, 86 changed); `diff -rq` against
  `~/.cyrius/versions/6.7.18/lib` is clean and `cyrius.lock` re-locked (113 / 113
  verified). No new compiler refusal reaches hapi, and no API it uses was renamed or
  deprecated.
- **Manifests with a CRLF or unterminated `---` now parse as ADR 0001 describes.**
  This is inherited from bayan, and visible:
  - **CRLF + `---\r\n`:** 6.6.20 did not see the delimiter, so the markdown body was
    parsed as manifest. `check --strict` refused it ("unknown key"), `inspect` silently
    ignored stray keys, and a `[[link]]` in the body **counted as a row**. Now the body
    is ignored, as on LF. *Migration:* a CRLF manifest whose rows sat below its `---`
    loses them. Move them above it.
  - **Blank first line, then `---`:** that line is now the delimiter (a `---` on line 1
    always was), so the header is empty and the manifest is refused with
    `[package].name is missing`. It used to parse.
  - **Unchanged:** LF manifests; a `--- notes` line, which is still header text; and a
    `---` with trailing spaces.

  Measured by running 1.0.12-on-6.6.20 and 1.1.0 side by side on ten delimiter edge
  cases. These are the only differences.
- **The release binary is 2.8× larger, all of it data.** `CYRIUS_DCE=1` output went
  194,744 → 542,520 bytes. The code segment is flat (+2.5 KB). The data segment went
  38.7 KB → 382 KB because 6.7.18's bayan unconditionally includes the Unicode casefold,
  category and normalization tables, and DCE drops dead code but not data. hapi never
  touches those pages: an interleaved `sync` A/B against 1.0.12 is flat (see
  `docs/benchmarks.md`). Upstream's to fix; `lib/` is not edited here.

### Tests

- New `1.1.0` section in `tests/hapi.tcyr`, three groups / 22 assertions:
  - **The reader rule pinned:** LF and CRLF bodies are not parsed, a final unterminated
    `---` parses, and `--- notes` is not a delimiter.
  - **Writer/reader agreement:** append, then parse the row back, for LF, CRLF, final
    `---`, final `---\r` and `--- notes`.
  - **Remove never edits the body.**

  Mutation-proven: against the 1.0.12 writer, 7 of them fail. Suite **387 / 387 across
  95 groups**, on x86_64 and on aarch64 under qemu.
- Re-verified on 6.7.18:
  - x86_64, `--aarch64`, `--agnos` and `CYRIUS_DCE=1` builds
  - `cyrius lint`: 0 warnings across all 21 `src/` files and `tests/hapi.tcyr`
  - `cyrius fuzz` and `cyrius bench tests/hapi.bcyr`
  - `scripts/concurrency-test.sh`
  - `scripts/agnos-smoke.sh` under mirshi: all four checks
  - the torn-tail guard, against the real binary
  - an end-to-end `adopt` + `rollback` on a CRLF package with a body example: the row is
    read, then removed, and the body survives

### Notes

- **`cyrius update` now honours the pin** (fixed upstream at 6.7.12). It still refreshes
  only the declared `[deps] stdlib` set unless given `--full`, so `cyrius lib sync --full`
  stays the way to keep hapi's full snapshot exact.
- **A pin move needs `cyrius lib sync --full` first** (6.7.12+). Until it runs,
  `cyrius deps` / `build` exit 1 and touch nothing.
- **Appending to a CRLF manifest writes LF lines.** The result has mixed line endings;
  the reader and `check --strict` accept it.
- **Next: 1.1.1 is the P(-1) audit and repairs.** Scope and the repair candidates this
  release and 1.0.12 turned up are in `docs/development/roadmap.md` § 1.1.1.

## [1.0.12] - 2026-10-28

> **A toolchain refresh that found a real aarch64 hole.** The bump itself needed no
> source change. Reading the upstream changelog for it did: cyrius 6.6.4 lists hapi among
> the consumers that hard-code the x86_64 `O_NOFOLLOW` value, and on arm64 that number
> means something else. Running the suite **on aarch64 for the first time** (under qemu)
> showed F-003's TOCTOU defence was absent there, and that the test harness itself was
> x86-only.

### Fixed

- **`O_NOFOLLOW` was spelled as the x86_64 literal, so the aarch64 build followed
  symlinks in `hapi_open_nofollow`.** `src/agnos_compat.cyr` OR'd `131072` (`0400000`)
  into the open flags. On x86_64 that is `O_NOFOLLOW`; on arm64 it is **`O_LARGEFILE`**,
  and arm64's `O_NOFOLLOW` is `0100000`. So on aarch64 `hapi_backup_copy` (the
  `--backup-to` snapshot taken before `link --force` and `adopt`) would follow a
  swapped-in symlink and copy its target into the "snapshot". That is exactly the F-003
  race the shim exists to close.

  Nothing caught it. The aarch64 target was compile-only in CI, and
  `test_open_nofollow_refuses_symlink` only ever ran on x86_64. Under qemu it fails:
  *"a symlink is refused"*, *"backup_copy refuses a symlink source"*, *"copy through
  symlink refused"*, plus an `-EEXIST` knock-on from the snapshot that should never have
  been written. The shim now spells the symbol (`flags | O_NOFOLLOW`), which each
  `lib/syscalls_*` peer has defined per target since cyrius 6.6.4. x86_64 compiles to the
  same constant. The bug is as old as F-003's fix itself: the literal entered
  `src/backup.cyr` at 0.9.0, and 1.0.10 moved it into the shim unchanged. Every aarch64
  build since then has carried it.
- **The test harness was x86_64-only.** `_test_file_size` called raw `syscall(8, …)`,
  which is `lseek` on x86_64 and something else on arm64, so six audit-trail assertions
  failed on aarch64 for a harness reason, not a hapi one. It now uses `xlseek`, as
  `src/audit.cyr` does. The three harness entry points (`tests/hapi.tcyr`, `.bcyr`,
  `.fcyr`) ended with `syscall(60, …)`, the x86_64 `exit`; they now spell `SYS_EXIT`, as
  `src/main.cyr` and `src/test.cyr` already did. **`cyrius test --aarch64`: 355 / 365
  before, 365 / 365 after.**
- **CI now runs the suite on aarch64.** New `ci.yml` step `Test (aarch64, under qemu)`
  installs `qemu-user` and runs `cyrius test --aarch64`. cyrius execs aarch64 test
  binaries through a hard-coded `/usr/bin/qemu-aarch64`, and hapi's ELFs are static, so
  nothing else is needed. A missing qemu **fails** the step (checked with qemu masked
  out: `FAIL: tests/hapi.tcyr (exit 127)`, exit 1); it does not skip. `release.yml`
  gates on `ci.yml`, so a release runs it too. The aarch64 build step stays: it proves
  the target compiles, and the new step proves it behaves.

### Changed

- **Toolchain `6.6.2` → `6.6.20`.** `lib/` resynced to the 6.6.20 full snapshot
  (`cyrius lib sync --full`, 113 files; five new: `alloc_cx`, `boxed`, `hashseed`,
  `poison`, `tls_hostid`). `diff -rq lib ~/.cyrius/versions/6.6.20/lib` is clean, so
  `lib/` mirrors the pin exactly. It had drifted at 1.0.11: only the declared modules were
  refreshed, and the rest of the tree was still the 1.0.4-era (6.5.35) snapshot. Nothing
  in `src/` trips a 6.6.3 – 6.6.20 refusal.

  Re-verified:
  - x86_64 build, plus the `--aarch64` and `--agnos` builds
  - a `CYRIUS_DCE=1` release build
  - `cyrius test`: 365 / 365 on x86_64, and on aarch64 under qemu
  - `cyrius lint`: 0 warnings across all 21 `src/` files and `tests/hapi.tcyr`
  - `cyrius fuzz` and `cyrius bench tests/hapi.bcyr`
  - `cyrius deps --verify`: 113 / 113
  - `scripts/concurrency-test.sh`
  - `scripts/agnos-smoke.sh` under mirshi: all four checks
  - the torn-tail guard, against the real binary: a trail whose last byte is not `\n`
    refuses `link` with exit 1, creates nothing, and leaves the trail untouched
- **Toolchain fixes hapi picks up.**
  - On agnos, `file_open` now bridges `O_EXCL` → `AO_EXCL` (6.6.4; agnos ≥ 1.56.56).
    Before, the bit was dropped, so `backup.cyr`'s and `manifest_write.cyr`'s exclusive
    creates opened an existing file and overwrote it in place.
  - `CYRIUS_DCE=1` no longer emits a data segment the code was not patched against
    (6.6.3).
  - A large environment can no longer make `--agnos` emit a Linux ELF, or make
    `CYRIUS_DCE=1` a silent no-op, while the build still reports OK (6.6.20).
  - `cyrius test` children get the whole environment, so `HOME` / `XDG_STATE_HOME` /
    `PWD` resolve in large shells (6.6.11).
- **Benchmarks flat**: cold 90 ms / warm 72 ms, trail byte-identical at 101,150 bytes /
  350 entries, zero warm growth. An interleaved A/B against 1.0.11-on-6.6.2 on the same
  kernel shows no toolchain delta (see `docs/benchmarks.md`). It was measured before the
  `O_NOFOLLOW` fix, which compiles to the same constant on x86_64.

### Notes

- **`cyrius update` ignores the manifest pin at 6.6.20.** It re-vendored `lib/` from
  `~/.cyrius/current` (6.7.18) rather than the pinned 6.6.20. Refresh `lib/` with
  `cyrius lib sync --full`. Recorded in `docs/development/state.md` § Toolchain.
- **`cyrius.lock` now exists.** Since 6.6.9, `cyrius deps` / `lib sync` write one for a
  stdlib-only project too (sha256 per vendored file plus a `cyrius<TAB><pin>` trailer),
  and upstream's note says to commit it. `deps --verify` fails on any vendored file the
  lock does not cover. It is untracked as of this release.
- Carried over from the retired roadmap note on the 6.6.6 bump: the stdlib's
  `file_replace_atomic` **writes through a symlink**. That is the wrong default for a
  symlink farm, because it edits the package source rather than the link. hapi uses
  neither it nor `file_write_atomic`; adopting either is a decision, not a drop-in.
- `docs/development/state.md`'s Version and Toolchain sections, missed at 1.0.11, are
  current again.

## [1.0.11] - 2026-09-11

### Changed

- **Toolchain `6.5.35` → `6.6.2`.** Migrated to the `Result` value form: 14 first-party
  file(s) changed. Build, tests and every bench/fuzz/distlib target re-verified.

## [1.0.10] - 2026-08-26

> **The 1.0.x hardening arc's last two findings — and a correction.**
> F-027 and F-031 were recorded as "blocked on an agnos runner" from the
> 2026-08-25 audit through 1.0.9. **That was wrong.** mirshi — the
> AGNOS→Linux syscall-translation supervisor — builds in this tree at
> 1.11.0, above the ≥1.10.2 hapi has required since 1.0.3, and runs an
> agnos-compiled ELF as a native Linux process. There was no missing
> runner; nobody had wired it up. Both findings were reproducible the
> whole time. Suite **365 assertions / 90 groups**, plus an agnos harness.

### Fixed
- **A relative package argument produced a non-absolute `abs_source` on
  agnos (F-027).** agnos has no `getcwd` — no per-process cwd in the
  userland ABI — so `_fsl_getcwd` returned `"."`, `fsl_to_absolute` handed
  back a still-relative path, and it flowed into the trail's
  `abs_source`, which ADR 0002 requires to be absolute. The failure was
  self-consistent, so `status` recomputed the same wrong value and
  reported OK: nothing ever flagged it.

  hapi now prefers `PWD` (agnos's kernel stages it into the init envp at
  exec) and, when the cwd genuinely cannot be determined, **refuses**
  rather than writing an entry that violates the format. The refusal
  propagates through `fsl_canonical_arg` — the single choke point 1.0.9
  introduced for user-supplied path arguments — to `link`, `status` and
  `adopt`, each of which now reports it and exits 1 instead of
  dereferencing a null manifest path.
- **`O_NOFOLLOW` was silently dropped on agnos, so F-003's defence did
  not exist there (F-031).** Not a bug in the bridge: agnos's entire
  `AO_*` open-flag set is RDONLY/WRONLY/RDWR/CREAT/TRUNC/APPEND/DIRECTORY
  and has **no no-follow bit to map to**. An attacker who swapped the
  regular file for a symlink between the probe and the copy got the
  symlink's target content written into the "snapshot", and
  `hapi_backup_copy` returned 0 as though it had worked.

  New `hapi_open_nofollow` centralizes the difference: atomic
  `O_NOFOLLOW` on Linux/macOS, and on agnos a `readlink` pre-check —
  using the `readlink`#70 peer hapi gained in 1.0.4 — that refuses with
  ELOOP when the path is a symlink.
  ⚠ **This narrows the window; it does not close it.** Between the
  readlink and the open, agnos offers no way to prove the two saw the
  same inode. The residual race is an accepted agnos boundary until the
  kernel grows a no-follow open flag — and it is strictly better than
  following the link unconditionally.

### Added
- **`scripts/agnos-smoke.sh`** — runs the `--agnos` build under mirshi,
  and CI runs it. Four checks: the binary loads and the agnos arg reader
  delivers argv (a scheme that has broken twice upstream), the
  environment gap is asserted rather than assumed, a relative package
  argument is refused rather than silently mis-resolved (F-027, verified
  **on the agnos target**), and the exit-code contract holds there too.
  A missing mirshi exits **2 = SKIP** and CI surfaces it as a warning,
  never as green — so an absent runner can never quietly read as "agnos
  is fine".

### Known limitations
- **mirshi passes no envp to the child**, so `getenv` returns null for
  everything and hapi cannot resolve a scope root under it. Real agnos
  stages `HOME=/ PWD=/` at exec, so this is a supervisor gap rather than
  a hapi defect — but it bounds what the harness can exercise: verbs
  that need a scope root are not reachable under mirshi yet. Asserted
  explicitly in the harness so it is noticed if it changes. It belongs
  upstream in the mirshi repo, not in hapi's issue tracker.

## [1.0.9] - 2026-08-25

> **The rest of the 1.0.x hardening arc, in one release.** Eleven
> findings — all of Tier 2 and all of Tier 3 — reproduced, fixed and
> regression-tested together. That empties the arc except for two
> agnos-target-conditional items that cannot be verified without a
> runner. No caller-visible surface change; the v1.0 contract stays
> frozen. Suite **361 assertions / 89 groups**.

### Fixed — hapi reported a world that was not on disk (Tier 2)
- **`link` created dangling symlinks, and `status` called them OK
  (F-022).** A row whose source is missing produced a symlink pointing
  at nothing, exit 0 — and `status`, which F-006 designates the
  *post-recovery source of truth*, reported `2 / 2 OK`. `link` now
  refuses (`--force` does not override it: the link would still dangle),
  and `status` classifies it `BROKEN`. One shared predicate,
  `fsl_source_present`, so the two verbs cannot drift apart. It also
  covers a case the finding did not name: a source that traverses a
  regular file returns ENOTDIR, not ENOENT, which an
  absence-only check would have missed. `hapi check` already caught the
  plain case since 1.0.7 — link and status were inconsistent with a
  shipped verb.
- **`hapi list` overcounted after a `--force` takeover (F-023).** The
  live-set was built from each package's *own* entries, so nothing could
  retire a claim when another package took the same target: two packages
  each reported owning the one symlink on disk. It is now a global
  per-target owner map — a create displaces the previous owner, and a
  remove only clears when the remover *is* the owner.
  ⚠ The obvious fix is a **41× slowdown**: building that map inside the
  per-package loop measures 0.665 s against 0.016 s on a benchmark-shaped
  trail, which would have blown the >2× gate wide open. The build is
  hoisted and indexed by a hashmap — 1.0× — and the `vec_set` cleanup it
  needed deletes ~34 lines of rebuild loops justified by a comment that
  was simply false (`lib/vec.cyr` has exposed `vec_set` all along).
- **`hapi link .` broke `sync`'s idempotency contract (F-024).** An
  unnormalized package-dir argument produced a `./`-bearing symlink body;
  every later canonical run recomputed the clean form, byte-compared, saw
  a mismatch and called it a conflict — so `sync`, whose contract *is*
  idempotence, refused with exit 1 and advised `--force`, which on a
  package with a real file conflict destroys that file. Arguments are now
  canonicalized at the three resolvers that derive an absolute path.
  ⚠ `fsl_compute_relative` and the four ownership-proof call sites are
  deliberately untouched — those verbs prove ownership by recomputing and
  byte-comparing, so changing the computation changes what they compare.
- **`package.ignore` is documented as reserved (F-025).** It is parsed,
  echoed by `inspect` and folded into the manifest hash, but no verb
  applies it — a user who lists `secrets.env` sees it confirmed and then
  linked live. Honouring it changes what a directory row materializes and
  how many audit entries a row writes, both frozen at v1.0, so it is a
  **v2.0** item. 1.0.9 ships the honesty: ADR 0001 marks it
  reserved-not-honoured, and the shipped example stops demonstrating a
  no-op silently.
- **`hapi sync --backup-to` was an advertised no-op (F-026).** The guide
  claimed *"`sync` inherits `--force`, and with it `--backup-to`"*. It
  does not — `sync` has no `--force`, so there is no destructive step to
  snapshot. Corrected in `guides/sync.md`, `guides/backup-to.md`,
  `state.md`, the module headers and `hapi --help`. The flag stays
  *accepted* on `sync` (the command surface is frozen) and is documented
  as inert.

### Fixed — write-path and argument hardening (Tier 3)
- **The audit entry was written after the mutation and never fsynced
  (F-018).** A failed append — a full state partition, a permissions
  change — left a symlink on disk that no recovery verb could see. hapi
  now **pre-flights** the trail before touching the filesystem, so the
  common failures refuse cleanly with nothing changed; appends through a
  local durable writer that fsyncs before dropping the lock and checks
  the close return; and refuses a **torn tail** (a trail whose last byte
  is not `\n` — appending onto it splices two entries into one line and
  the reader drops *both*). If an append still fails, exactly the one
  link it belonged to is undone — never the earlier ones in the run,
  which are recorded and reversible, and unwinding them would need
  further appends that are failing by construction.
- **`--root` and `--backup-to` swallowed a following flag (F-019).**
  `hapi link --root --dry-run pkg` consumed `--dry-run` as the root
  value; because the capability check passes whenever cwd is under
  `$HOME`, a run the user asked to be a no-op created a directory
  literally named `--dry-run`, planted a symlink and appended to the
  trail, at exit 0. A value that is itself flag-shaped is now rejected
  with exit 2 across all eight sites. (The two hand-counted `eprint`
  lengths this replaced were each one byte short and wrote a stray NUL
  to stderr.)
- **A package could steer where `--backup-to` wrote (F-020).**
  `[package].name` is validated only for non-emptiness and was
  interpolated raw into the destination, so a manifest naming itself
  `../../../pwned` put the snapshot of the user's file *above* the
  directory the user named. The name is now reduced to one filename-safe
  component. Sanitized rather than refused on purpose: the composer has
  no error channel and both callers read 0 as "no backup requested", so
  refusing would **silently skip the snapshot** at the exact moment the
  original is about to be deleted. This is not a capability check —
  `--backup-to`'s destination stays deliberately uncapped, per the
  audit's accepted boundary; what is restored is that the user's
  directory receives the bytes.
- **Created parent directories ignored umask (F-029).** A hardcoded 0700
  meant a `--root` deployment produced config directories the consuming
  service could not traverse. `fsl_mkdir_parents_mode` now lets the
  caller choose: `link_create` asks for 0777-through-umask, while hapi's
  own state directory and the `--backup-to` destination keep 0700
  deliberately — snapshots are written 0644, so the directory is the
  only thing holding that line.
  ⚠ **Leftover directories are NOT auto-pruned, and that is deliberate.**
  The trail records the symlink, not which directories hapi created, so
  any unlink-time prune is an *inference*. `rmdir` cannot remove a
  non-empty directory, but it can still remove one the user made on
  purpose, or drop a mode the user set — on `~/.ssh` that is a security
  regression hapi would have caused while claiming to reverse itself.
  hapi's rule is that it removes only what it created, *with proof*. The
  real fix is an additive `created_dirs` trail field; it is on the
  roadmap.
- **A trailing-slash target left a stray directory (F-032).**
  `symlink(2)` can never create a path spelled with a trailing `/`, but
  `mkdir_parents` had already materialized the directory — so a
  correctly-refused run still left residue. Refused before the mkdir.
- **`hapi inspect` returned the wrong exit code for a flag (F-033).** It
  parsed no flags at all, so any flag fell through to exit 1 ("bad
  manifest") instead of the exit 2 ADR 0005 specifies for bad usage.

### Still open
- **F-027 and F-031 are agnos-target-conditional** and are the only arc
  items left. Neither can be reproduced or regression-tested without an
  agnos/mirshi runner, so they are not guessed at; the audit continues to
  say *unverified on agnos*. The runner is the blocking item.

## [1.0.8] - 2026-08-25

> **The 1.0.x hardening arc's Tier 1 is closed.** F-015 — and with it
> F-002, open since the 2026-05-23 audit — is fixed: hapi's capability
> boundary now decides on the *physical* location of a target, not its
> spelling. No caller-visible surface change; the v1.0 contract stays
> frozen. Suite **323 assertions / 84 groups**.

### Fixed
- **A symlinked parent directory put a target outside `$HOME` on a
  plain `hapi link`, and `--force` then deleted what was there
  (F-015 / F-002).** `~/.config -> /mnt/other/etc` is an ordinary
  convenience symlink — or arrives with a restored backup or a shared
  dotfiles repo. `fsl_lexical_normalize` collapses `..` but treats every
  component as a plain name, so a row targeting `.config/foo` looked
  contained and was not.

  Measured, all with **no flag at all**: a bare `hapi link` wrote a
  symlink outside `$HOME` and exited 0, recording the *unresolved*
  in-`$HOME` path in the trail so nothing downstream could tell. With a
  file already there, hapi refused — as an ordinary file conflict —
  and advised `--force`; **following that advice destroyed the file
  outside `$HOME`** and left `status` reporting `1 / 1 OK`.

  New `fsl_resolve_path` walks a path component by component and follows
  a symlink at every one, hop-capped at 40 like the kernel's own ELOOP
  budget, keeping absent components literal (hapi creates parent
  directories, so an absent parent is routine). `cap_target_allowed`
  decides on the resolved location, resolving the scope root too so a
  `$HOME` that is itself reached through a symlink does not cause a
  false refusal. An escape is a **`LINK_ACT_ESCAPE`, which `--force`
  does not override** — mirroring the existing rule for directories —
  and is reported before the generic conflict message so it never
  carries the `--force` advice. `adopt`'s 1.0.5 containment check is
  upgraded to the same resolved test.

  ⚠ **`--root` is not the escape hatch, and the first draft of this
  message said it was.** `--root` re-roots where *every* manifest target
  resolves, which is a different operation from authorizing one
  symlink's destination. The grant is `HAPI_ALLOWED_ROOTS`, ADR 0005's
  actual capability mechanism, and it says what is meant: this location
  is authorized. Verified end to end — refused bare, refused under
  `--force` with the outside file intact, permitted once the destination
  is allowlisted, and an ordinary in-`$HOME` package unaffected.

### Changed
- **`docs/benchmarks.md` gains a 1.0.8 row.** Resolving every target's
  parent per component costs **~10% cold / ~13% warm** (100 ms / 86 ms,
  from 91 / 76). That is the price of the capability boundary actually
  holding, it is recorded rather than absorbed, and it is well inside
  the >2× regression gate; warm audit growth stays 0 bytes and the trail
  is still byte-identical at 101,150 bytes.

## [1.0.7] - 2026-08-25

> **1.0.x hardening arc — the rest of the manifest write path.** F-021
> and F-028, the two findings left on the path 1.0.6 locked. That closes
> `issues/2026-08-25-manifest-write-integrity.md` entirely. No
> caller-visible surface change; the v1.0 contract stays frozen. Suite
> **307 assertions / 81 groups**.

### Fixed
- **A quote in a filename silently rewrote the manifest row (F-021).**
  `manifest_append_link_row` wrote `source` / `target` raw, so adopting
  a file named `.ev"il` produced `source = "ev"il"` and `hapi inspect`
  read it back as `ev` — hapi's declared state describing a file that
  does not exist, at exit 0. A later `link` / `sync` would act on that
  row.

  ⚠ **Escaping is not the fix, and finding out why changed it.** The
  audit proposed mirroring the parser's escaping contract; the parser
  turns out not to have one. Its `\`-skips-the-next-byte rule stops a
  quote from *terminating* the value but never strips the backslash, so
  a written `ev\"il` parses back as the six characters `ev\"il` —
  still not the filename. There is no un-escape half to mirror, and
  adding one would change how every existing manifest parses: an ADR
  0001 frozen-surface change, so v2.0.

  hapi therefore **refuses to write a row it cannot faithfully
  represent** — `"`, `\`, and control bytes — rather than writing one
  that quietly means something else. `adopt` checks before the rename,
  so nothing is moved: the file stays where it is with a message naming
  the reason. Ordinary names are unaffected.
- **A crash mid-`adopt` left the file invisible to every verb (F-028,
  detection half).** `adopt` renames the file into the package before it
  writes the row, so a SIGKILL, an OOM kill or a closing lid in that
  window strands the user's dotfile in the package with **no row, no
  symlink and no trail entry** — and every other verb reports a clean
  world, because they all start from manifest rows. Only a directory
  walk can see it.

  `hapi check` now compares the manifest against the package directory
  in both directions: a row whose source is missing, and a file in the
  package that no row claims. Staging leftovers (`hapi.cyml.<pid>.tmp`)
  are correctly not orphans. Exit 1 on divergence, which is what a check
  verb is for; the exit-code contract is unchanged.

  This is detection, not prevention, and deliberately so — true
  crash-atomicity means writing an intent record before the rename,
  which is an **ADR 0004 revision**, not a patch. It stays on the
  roadmap.

### Changed
- **`fs` is no longer a dead dependency.** `check`'s directory walk uses
  `lib/fs.cyr`'s `dir_list`, which already handles both the Linux and
  agnos dirent layouts — so hapi does not hand-roll a per-target dirent
  parser, which is the exact class of divergence this arc keeps finding.
  The audit's "declared but unused" note on `fs` is closed; `slice`
  remains unused.

## [1.0.6] - 2026-08-25

> **1.0.x hardening arc — Tier 1, both open items.** The trail reader
> (F-007 / F-016 / F-017) and the manifest writer's concurrency
> (F-012). Every one of them ends the same way: a verb reporting
> success having done the wrong thing, or nothing at all. No
> caller-visible surface change; the v1.0 contract stays frozen. Suite
> **295 assertions / 79 groups**, plus a new shell harness for the
> defect `cyrius test` structurally cannot express.

### Fixed
- **`rollback` reversed the wrong window once the trail passed 256 KB
  (F-007).** `audit_read` read the *first* 256 KB of an append-only
  file, so past that point it could not see the most recent checkpoint
  marker, fell back to `start = 0`, and reversed the **oldest still-live
  links** — settled dotfiles the user had not touched in months — while
  leaving the recent work in place. Exit 0, reported as success. The
  user's mental model is "undo what I just did"; the action taken was
  the exact opposite.

  Measured on a real 800-entry / 328,800-byte trail: a checkpoint, one
  new package linked, then `hapi rollback` — **637 settled links
  destroyed, and the one link the user wanted undone left in place.**
  Post-fix the same fixture reverses `1 / 1 entries`, exactly the link
  past the marker. The read is now sized from the file (`xlseek`
  SEEK_END, the same shape 1.0.5 used to fix F-009), with one byte of
  headroom so a trail that grows mid-read is detected rather than
  silently truncated.
- **An interior malformed line was silently skipped (F-016).** A bad
  sector, a partially-flushed extent after a crash, or an accidental
  editor save damaged one entry, and every consumer stepped over it:
  `rollback` claimed complete success while the link that line recorded
  survived on disk, `unlink` missed it, `list` undercounted. hapi's rule
  is that conflicts surface explicitly, and a damaged trail is a
  conflict with the user's own history — it is now refused, naming the
  line number. A **trailing** partial line is still dropped silently:
  that is the writer's atomic-append contract, and it keeps its own
  standing test.
- **An unreadable trail was swallowed as "empty" (F-017).** A
  permissions change, a failing disk or fd exhaustion made `list`,
  `rollback` and `unlink` exit 0 having done nothing, so a script keying
  on exit status concluded the rollback had succeeded. `ENOENT` is still
  `Ok(empty)` — that is the legitimate first-run case — but every other
  open or read failure is now an error.

- **Concurrent `hapi adopt` committed every filesystem mutation and
  dropped the manifest rows recording them (F-012).** The
  read-modify-write on `hapi.cyml` was unsynchronized and staged through
  a fixed `hapi.cyml.tmp`, so two adopts against one package used the
  same staging file and the last rename won.

  Measured on a 3 MB manifest with 16 concurrent adopts: **16 files
  moved, 16 symlinks planted, 16 trail entries — and 1 manifest row.**
  hapi's declarative state stopped describing its own filesystem, and
  because `status` walks manifest rows it could not see the orphans.
  Two changes, and the order matters — the first alone made things
  *worse*: staging is now `hapi.cyml.<pid>.tmp` opened `O_EXCL` (before
  it, 14 of the 16 adopts failed outright and were at least visible;
  after it they all "succeeded" and 15 rows vanished silently), and the
  read-modify-write now holds `LOCK_EX` for its whole duration. The lock
  is taken on the **package directory**, not the manifest: the manifest
  is replaced by rename, so writers flocking it by path can hold two
  different inodes and exclude nobody — and locking the directory leaves
  no `.lock` artifact in the user's dotfiles repo. Post-fix: 16/16 on
  every axis across repeated runs.

### Added
- **`scripts/concurrency-test.sh`** — the regression harness for F-012.
  The defect needs two hapi *processes*, and `.tcyr` cannot fork while
  hapi is syscall-only by rule, so there was no honest way to express it
  inside `cyrius test`. It lives alongside, the way the benchmark
  harness does, and CI runs it. Mutation-proven: dropping the lock turns
  it RED with `manifest rows: got 1, expected 16`.

### Changed
- **`audit_read_r` / `audit_read_default_r`** return a `Result`, and
  `rollback` / `unlink` / `list` use them: on a trail that exists but
  cannot be read or parsed, each prints what is wrong (with the line
  number for a corrupt entry) and exits 1 rather than acting on a
  partial view. `audit_read` remains as a vec-returning wrapper for call
  sites that genuinely cannot act on an error.
- **`tests/hapi.tcyr`'s "drops malformed lines" group is now "refuses an
  interior malformed line".** That test asserted the behaviour F-016
  identifies as the defect — it was encoding the bug as the contract, so
  it changed with the fix. Each of the three repairs is mutation-proven:
  reverting them turns the new group RED with ten distinct failures,
  including F-007's `got 882, expected 1000` as the old cap truncates
  mid-trail.

## [1.0.5] - 2026-08-25

> P(-1) hardening sweep per CLAUDE.md, and the repairs out of it.
> **Six HIGH-severity defects fixed** — two heap overflows reachable from
> an ordinary manifest, two silent destructions of user bytes, one
> capability escape, and one argument-parsing bug that made
> `hapi rollback <pkg>` reverse the entire trail. Full record in
> [`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md),
> including the **twenty findings that remain open**. No caller-visible
> surface change; the v1.0 contract (command surface, ADR 0001 manifest
> schema, ADR 0002 audit-trail format) stays frozen and byte-identical.
> Suite **280 assertions / 76 groups**; `cyrius lint` clean tree-wide;
> x86_64, aarch64 and agnos all build.

### Fixed
- **`hapi_mf_canonicalize` ignored its `cap` argument — heap overflow,
  SIGSEGV, exit 139 (F-014).** A 3,000-row manifest (138 KB, well under
  the cyml read cap) killed `hapi link`, `hapi sync` **and
  `hapi link --dry-run`** with an exit code outside the published 0/1/2
  contract and no diagnostic. `--dry-run` is not spared because the
  manifest hash is computed before the dry-run branch. The overflow
  lands on the `sorted` vec the row loop is iterating, so the faulting
  pointer is built from manifest bytes. Writes are now bounded and
  `hapi_mf_canonical_size` sizes the caller's buffer, so that manifest
  **links successfully** rather than merely refusing. It refuses rather
  than truncates when a buffer really is too small: these bytes are the
  `sha1c:` `manifest_hash` preimage frozen by ADR 0002, so a short
  prefix would quietly hash a different document. Canonical output is
  unchanged for every manifest that already fit — asserted by an
  exact-size byte comparison, the four standing canonical-hash groups,
  and a benchmark trail that is byte-identical at 101,150 bytes.
- **Audit entry composers ignored `cap` — out-of-bounds heap write that
  destroyed the trail (F-008).** `_audit_emit_field` wrote unbounded
  into a fixed `alloc(4096)`, and both bounds are attacker-sized: the
  values come from the manifest and the JSON escaper expands a control
  byte 6:1. A legal 19×200-character target composed 8,027 bytes into
  4,096; the same target as `0x01` bytes composed 46,028 — a ~42 KB
  overflow of attacker-chosen content. The post-format
  `audit_ensure_dir()` then bump-allocated *on top of* the formatted
  bytes, so the line reaching disk carried spliced heap content and a
  raw NUL: `link` exited 0, the trail stopped parsing, and `unlink`
  reported `unlinked 1 / 1` while the symlink stayed on disk. Writes are
  now bounded and each buffer is sized from its own inputs; an entry
  that cannot fit refuses through the existing
  `hapi: audit-trail write failed` / exit 1 path. Never truncates — a
  short line has no `\n`, so the next entry concatenates onto it and the
  reader drops both.
- **`adopt` applied no capability bound to its `<file>` argument
  (F-011).** `hapi adopt /path/outside/$HOME/f pkg` with **no `--root`**
  exited 0, moved the file out of its directory and planted a symlink
  there — a direct violation of CLAUDE.md's *"do not write outside
  `$HOME` without an explicit `--root` flag"*. `adopt`'s `<file>` is a
  write target and is now checked like one, via a new
  `cap_within_scope(path, scope_root)` that lexically normalizes both
  sides before a component-boundary match. Absolute and `../` escapes
  refuse with exit 1 and leave the file untouched; a file inside `$HOME`
  still adopts; and a path outside `$HOME` **with** a `--root` grant
  still adopts, so the capability grant keeps working.
- **`hapi rollback <pkg>` reversed the entire trail (F-013).** Every
  verb silently discarded positional arguments it had no slot for, so a
  user scoping a rollback to one package destroyed every link in the
  visible trail at exit 0 — and `hapi link A B` reported complete
  success having linked only A. Every verb now rejects an extra
  positional with exit 2 and a named diagnostic. Legitimate forms are
  unaffected.
- **A manifest past 256 KB was truncated and the truncation committed
  (F-009).** `_hmw_slurp` read into a fixed `alloc(262144)` and stopped
  at the cap with no signal, and both callers hand the buffer straight
  to the atomic rewrite — so `hapi adopt` on a 300 KB manifest exited 0
  having permanently deleted the markdown body and everything after it.
  ADR 0001 sanctions an arbitrarily long body below the `---`
  separator, so the size is reachable without doing anything unusual.
  The buffer is now sized from the file, with one byte of headroom so a
  file that grew mid-read is refused rather than committed short.
- **`--backup-to` destroyed one snapshot when two rows shared a target
  basename (F-010).** The destination is `<ts>-<pkg>-<basename>`, so
  `a/config` and `b/config` composed the same path inside one second and
  the second copy overwrote the first — destroying exactly the bytes
  `--force` was about to delete — while both trail entries pointed
  `backup_path` at the survivor. The composer now suffixes `-2`, `-3`, …
  until the name is free, and the copy opens `O_EXCL` instead of
  `O_TRUNC` as the backstop. Two adjacent repairs rode along: a `w == 0`
  write result is an error rather than a silent spin, and the write-side
  `file_close` return is captured, since a deferred error on the last
  copy of the bytes must not read as success.

### Changed
- **CI compiles `--aarch64` and `--agnos`, not just x86_64.** Two
  compile-only steps in `ci.yml`. Cross-compilation is all a GitHub runner
  can do for these — there is no aarch64 runner and agnos needs mirshi — but
  compiling is the check that was missing: `--aarch64` silently stopped
  building at 1.0.2 over a bare `SYS_OPEN` and nothing noticed until 1.0.4,
  because CI built one target. That matters more now that cyrius 6.5.1 makes
  a wrong argument count a hard error rather than a warning, so an unbuilt
  target can break on drift the x86_64 build accepts.
- **`cyrius lint` is clean across `src/` AND `tests/`** — 0 deferrals,
  0 warnings, 0 notes. Six untracked deferrals cleared: two were the
  linter matching `XXX` inside the `\uXXXX` escape notation
  (`#skip-lint`), two were real deferrals that now carry their tracking
  cross-reference (`cap.cyr` → F-002, `cmd/sync.cyr` → the sync-prune
  issue), two were stale prose describing milestones that shipped long
  ago. Ten over-long lines and a stray blank-line run cleared: seven of
  them were manifest fixtures in `tests/hapi.tcyr` written as one long
  escaped string, now **real multi-line literals** — the fixture reads
  like the manifest it is, at a third the line length. The one fixture
  that stays escaped is the cosmetic-insensitivity case, whose whole job
  is to carry trailing whitespace and a two-blank-line run; it is
  `#skip-lint` with the reason written next to it.
- **`link_probe`'s directory discrimination moved onto `io.cyr`'s
  portable wrappers** — `file_open` / `xgetdents` / `file_close` instead
  of `sys_open` + two raw `syscall(...)` numbers. Clears the last two
  lint notes and, more to the point, retires the last instance of the
  exact pattern that kept `--aarch64` from building between 1.0.2 and
  1.0.4. Behaviour is unchanged on every target; the block still sits in
  the non-agnos `#else` arm.
- **The sweep's open findings are tracked as arc work, not an audit
  appendix.** `docs/development/roadmap.md` gained a **1.0.x hardening
  arc** ahead of the additive v1.x bucket, bucketing all twenty by blast
  radius (Tier 1 silent data loss / Tier 2 wrong reporting / Tier 3
  hardening / target-conditional) with explicit exit criteria: additive
  growth does not resume while a Tier 1 finding is open. Three new issue
  files carry the Tier 1 and Tier 2 clusters, and `state.md` points at
  them. The roadmap's kavach migration bullet — the dep gate the audit
  found void — is withdrawn in place with the reason.

### Known limitations
- **Twenty audit findings from this sweep remain open in the shipped
  1.0.5.** They are recorded in
  [`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md) and
  scheduled as the **1.0.x hardening arc** in
  [`docs/development/roadmap.md`](docs/development/roadmap.md). Tier 1,
  where the failure is silent data loss or a wrong destructive action:
  **F-007**, the trail reader's 256 KB head cap, which makes `rollback`
  reverse the *oldest still-live* links once the trail outgrows it;
  **F-012**, the unlocked manifest read-modify-write, under which
  concurrent `adopt` commits every filesystem mutation and drops the row
  recording it; and **F-015**, a symlinked intermediate component in a
  manifest target escaping `$HOME` with no `--root` at all.
- **F-002's dependency gate is void.** ADR 0005 parks the symlink-escape
  fix on kavach exposing a stable `cap_check(scope, action)` API.
  kavach is at 3.12.3 and is a *sandbox execution* framework — ten
  backends, strength scoring, credential proxy, HMAC audit chain — whose
  entire public path surface is `kavach_path_exists`. There is no such
  API and none is planned, and adopting it would collide with hapi's
  no-process-spawning rule. F-002 is hapi-owned work now, and the
  primitive it needs (`hapi_readlink`, portable across all three
  targets) landed in 1.0.4.
- **Six files still fail `cyrius fmt --check`** under 6.5.28's indent
  contract, unchanged from 1.0.4. Deliberately not reformatted inside a
  release cut, because 6.5.28 also made `cyrius fmt <file>` rewrite in
  place — the remedy the tool prints would silently rewrite the
  ADR-0002-frozen `src/audit.cyr` and the 280-assertion suite.

## [1.0.4] - 2026-08-25

> Toolchain + vendored-stdlib refresh (cyrius `6.4.22` → `6.5.35`),
> the agnos `readlink`#70 `link_probe` work that had been sitting in
> Unreleased, and one latent audit-trail defect the new toolchain's
> call-arity check surfaced. No caller-visible surface change; the
> v1.0 contract (command surface, ADR 0001 manifest schema, ADR 0002
> audit-trail format) stays frozen. Suite **246 assertions / 71
> groups**, all passing; `--agnos` build green; `cyrius lint` clean.

### Fixed
- **`rollback` emitted a junk `backup_path` when reversing an `unlink`.**
  `_hrb_reverse_unlink` (`src/cmd/rollback.cyr`) called the eight-argument
  `audit_append_link_r` with seven: the optional `backup_path` was never
  passed, so the callee read an uninitialized argument slot and the replay
  entry could carry the field with a meaningless value. The reversal only
  ever recreates a symlink into an **absent** target — nothing is
  destructively overwritten, so there is no snapshot to record — and the
  call now passes `0`, the documented "no backup" value (`src/audit.cyr`
  emits the additive field only when `backup_path != 0 && strlen(...) > 0`).
  ADR 0002's frozen **required**-field set is untouched; this only stops an
  *optional* field from appearing where it has no meaning. The mismatch dates
  to 0.8.0, when `--backup-to` gave `audit_append_link_r` its eighth
  parameter and this call site was not updated with it. It shipped in every
  release from 0.8.0 through 1.0.3 because a wrong argument count was a
  **warning** until cyrius 6.5.1 — the compiler emitted the binary anyway,
  so the only outward sign was one easily-missed line. 6.5.1 made it an
  error (`_CHECK_ARITY` sets `_had_error`, no binary produced), which is why
  adopting 6.5.35 is what surfaced it. Locked by a new regression group —
  mutation-proven: it goes RED when the argument is replaced with a non-zero
  path. Three call sites in `tests/hapi.tcyr` carried the same omission (plus
  one nine-argument `audit_format_link`) and are fixed with it.
- **`cyrius build --aarch64` did not compile.** `src/fs_link.cyr`'s
  `link_probe` opened the probe fd with a bare
  `syscall(SYS_OPEN, path, 0, 0)`, and there is no `SYS_OPEN` on aarch64
  Linux — it has `openat(2)` only, so `lib/syscalls_aarch64_linux.cyr`
  deliberately declines to define the constant (its own comment notes that
  56 there is `openat` while 56 on x86_64 is `io_setup`, so a bare number
  would be worse than an undefined one). The site now calls the named
  `sys_open(path, flags, mode)` wrapper, which every non-agnos table
  provides and which routes through `SYS_OPENAT` + `AT_FDCWD` on aarch64.
  It sits in the non-agnos `#else` arm, so agnos's differently-shaped
  `sys_open(name, namelen, flags)` is out of reach. Pre-existing and
  unrelated to the pin bump — CI has never built aarch64 — and it is the
  last un-swept site from the 1.0.2 named-wrapper migration that actually
  broke a target. x86_64 and agnos codegen are unaffected; the suite is
  unchanged at 246.

### Changed
- **Toolchain pin `6.4.22` → `6.5.35`** (`cyrius.cyml` `[package].cyrius`)
  and **vendored `lib/` resynced to the 6.5.35 snapshot**
  (`cyrius lib sync --full`): 108 files — 67 updated, 10 new
  (`async_macos.cyr`, `async_win.cyr`, `thread_macos.cyr`, and the seven
  files of the `lib/unicode/` package directory), none removed. hapi's
  declared `[deps] stdlib` set is unchanged, and nothing hapi calls was
  renamed, moved, or removed across the span — the three stdlib symbols
  retired between the pins (`_arena_alloc` / `_arena_reset` in `alloc`,
  `_macho_capture_args` in `args_macos`, `json_v_parse_str` in `bayan`)
  have no hapi call sites. The stale `lib/agnosys.cyr` bundle — vendored at
  scaffold, dropped from the upstream snapshot at 6.4.x, never `include`d by
  hapi — is pruned, so `lib/` again mirrors the pin exactly.

  ⚠ **The shipped binary roughly doubles: ~280 KB → 562,992 bytes.** That is
  the cost of the bigger 6.5.35 stdlib (`bayan` alone gained 439 functions
  between the pins), not of anything hapi added — hapi's own source barely
  moved this release. Note also that `CYRIUS_DCE=1`, which the release
  workflow sets, now produces a binary of **exactly the same size** as a
  plain build (byte-different, same length): this cyrius NOPs dead
  functions in place rather than removing them, so the flag no longer buys
  the size reduction `release.yml`'s comment still claims for it. Nothing
  is broken by that — the DCE smoke run passes — but the artifact is
  larger, and a future release that cares about download size should take
  that up with the toolchain rather than expect DCE to fix it.
- **`link_probe` on agnos uses `readlink`#70, not stat-classification.**
  agnos grew a ring-3 `readlink#70` — the symlink-introspection peer of
  `symlink#63` — so `src/fs_link.cyr`'s agnos branch probes readlink FIRST:
  `n > 0` ⇒ it is a symlink and hapi already holds the target to byte-compare
  against the manifest (a DANGLING link included — #70 SEES it, where
  `stat#33` reported it absent); otherwise it falls back to `stat#33` to split
  file/dir/absent (stat follows, but the path is not a symlink there). This
  closes the agnos-only gap 1.0.3 documented under *Known limitations* — hapi
  could create links but could neither see an existing one nor read its target
  for `status` / reconcile. Linux/macOS `link_probe` and every other target
  path are byte-unchanged.
- **`hapi_readlink` now calls the native `sys_readlink` peer on agnos.** The
  6.5.35 snapshot ships `sys_readlink(path, pathlen, buf, buflen)` in
  `lib/syscalls_x86_64_agnos.cyr`, so the shim in `src/agnos_compat.cyr` drops
  its locally-declared `AGNOS_SYS_READLINK = 70` and the raw `syscall(...)`
  form — exactly the collapse the shim's own comment planned for, and the same
  path `hapi_symlink` took for #63 at the 6.4.x refresh. The agnos/Linux
  divergence is now only the arity.
- **`hapi --version` derives its number from `CYRIUS_PKG_VERSION`.**
  `hapi_print_version` (`src/main.cyr`) carried a hand-synced `"hapi 1.0.3"`
  literal that had to be bumped in lockstep with `VERSION` — an
  undocumented third sync point beside `VERSION` and the CHANGELOG header.
  cyrius 6.5.21 exposes the resolved `[package].version` (i.e.
  `${file:VERSION}`) as the compile-time constant `CYRIUS_PKG_VERSION`, and
  6.5.34 made it visible inside `include`d files as well, so the literal is
  retired and `VERSION` is the single source. Output shape is byte-identical
  (`hapi <X.Y.Z>`), which the release workflow's smoke step already asserts
  against the git tag.

- **CI installs the toolchain with the upstream installer, not a hand-rolled
  untar.** Both workflows read the `cyrius.cyml` pin and pipe it to
  `scripts/install.sh` from the cyrius repo, then assert
  `~/.cyrius/versions/<pin>/lib` exists before going further. The old block
  untarred the release asset into a flat `$HOME/.cyrius/{bin,lib}` — the
  pre-6.5 layout — which 6.5.x's `cyrius deps` rejects outright:
  `error: cyrius.cyml pins version 6.5.35 but it is not installed at
  ~/.cyrius/versions/6.5.35/lib`. That is what broke CI on this pin bump. The
  installer lays out `versions/<v>/{bin,lib}` and symlinks `bin/` and `lib/`
  at it, and additionally does SHA256 + Ed25519 signature verification the
  old block skipped — which also had `|| true` on every `cp`, so a
  half-copied toolchain reported success. Same pattern as darshana / patra /
  libro. Verified end to end against a from-scratch install into a scratch
  `CYRIUS_HOME`: the snapshot lands with 108 `.cyr` files, `cyrius deps`
  exits 0 and leaves the vendored `lib/` byte-identical, and build + suite +
  the release DCE smoke all pass.

### Known post-upgrade items
- **`cyrius fmt --check` now fails on six files** — five in `src/`
  (`agnos_compat`, `audit`, `fs_link`, `cmd/adopt`, `cmd/link`) plus
  `tests/hapi.tcyr`. 6.5.28 gave `fmt` a canonical continuation-indent
  contract (2 spaces per open paren, 4 accepted, deeper rejected) that
  hapi's existing style predates, so `cyrius audit`'s fmt step is red purely
  from the toolchain move. Not reformatted here on purpose: **6.5.28 also
  made `cyrius fmt <file>` rewrite in place** (stdout-only before; `--dry`
  is the old behaviour), and reflexively running the remedy the tool prints
  would silently reformat the ADR-0002-frozen `src/audit.cyr` and the
  246-assertion suite inside a release cut. `ci.yml` does not run `fmt`, so
  nothing is blocked. Review with `cyrius fmt <file> --dry` and reformat as
  its own commit after the tag.
- **Two `cyrius lint` line-length warnings** (`src/manifest.cyr:25`,
  `src/manifest_write.cyr:80`, both over 120 chars), and a new lint *note*
  on `src/fs_link.cyr:89` recommending `lib/io.cyr`'s `xgetdents` over the
  raw `SYS_GETDENTS64` for agnos-bound directory code. `cyrius lint
  src/main.cyr` is clean; these surface per-file.
- **`fs` and `slice` are declared but unused** in `cyrius.cyml`
  `[deps] stdlib` — zero `fs_*` and zero `slice_*` call sites. `lib/fs.cyr`
  now carries 6.5.24's `#host_only` annotation, which is a hard error under
  a kernel-mode build, so hapi is carrying its only `#host_only` module for
  no benefit. Dropping both is a post-tag cleanup, not a release change.
- **`src/manifest.cyr` reaches `bayan` through deprecation shims** —
  `cyml_parse_file_r` / `cyml_doc_header` / `cyml_doc_header_len` are
  one-line forwarders onto the real `bayan_cyml_*` entry points. Pure
  forwarders today, deletable upstream at any minor bump with no
  compile-time warning until they vanish. Three-line migration, post-tag.

### Removed
- **Known limitation "symlink introspection is unavailable on agnos"**
  (recorded at 1.0.3). agnos `readlink#70` plus the native cyrius peer close
  it: hapi can now see an existing link and read its target on agnos, so
  `status` / reconcile behave as they do on Linux. agnos still exposes no
  `lstat` and no `getcwd` — `link_probe` needs neither (readlink no-follows
  the final component), and `_fsl_getcwd` continues to return `"."` there.

## [1.0.3] - 2026-07-08

> agnos target support + toolchain/vendored-stdlib refresh
> (cyrius `6.2.24` → `6.4.22`). hapi now compiles `--agnos` and runs
> under mirshi (>= 1.10.2), unblocking it in the agnos-dev docker
> image. No caller-visible surface change; the v1.0 contract (command
> surface, ADR 0001 manifest schema, ADR 0002 audit-trail format)
> stays frozen. Suite still **242 assertions / 66 groups**, all passing.

### Added
- **agnos target support** (`cyrius build --agnos src/main.cyr`).
  New `src/agnos_compat.cyr` centralizes the syscall-ABI divergences
  behind thin wrappers
  (`hapi_unlink`/`hapi_rename`/`hapi_fsync`/`hapi_symlink`/`hapi_mkdir`)
  that forward verbatim on Linux/macOS. `link_probe` classifies via
  `stat` (#33) on agnos; `hapi_symlink` uses the native agnos
  `sys_symlink` (#63); `hapi_fsync` maps to `sync` (#12); `hapi_mkdir`
  bridges the `(path, mode)` → `(path, pathlen)` ABI and treats an
  existing directory as success.

### Changed
- **Toolchain pin `6.2.24` → `6.4.22`** (`cyrius.cyml`
  `[package].cyrius`) and **vendored `lib/` resynced to the 6.4.22
  snapshot** (`cyrius lib sync --full`, 98 files). The refresh brings
  the agnos peer's native `sys_symlink` — so `hapi_symlink` calls it
  directly rather than a locally-defined syscall number — and an
  agnos-aware `file_append_locked` (LOCK_EX hold + explicit `SEEK_END`,
  since the agnos kernel does not honor `AO_APPEND` yet), so hapi no
  longer ships its own agnos append shim.
- **`src/fs_link.cyr` — per-target syscall paths.** `link_probe` uses
  `stat` (#33) mode-nibble classification on agnos (agnos has no
  `readlink`); the Linux `readlink` + `getdents64` path is unchanged
  behind `#else`. `_fsl_getcwd` returns `"."` on agnos (no `getcwd`
  syscall). `SYS_GETDENTS64` / `SYS_GETCWD` references are now
  Linux-gated so the agnos build resolves.

### Known limitations (agnos)
- **Symlink introspection is unavailable on agnos.** agnos exposes no
  `lstat` and no `readlink` to ring-3, and its `stat` follows the final
  symlink component (kernel `ext2_path_lookup`). So on agnos hapi cannot
  yet SEE an existing symlink or read its target: a symlink to an
  existing target classifies as that target's type, and its target
  cannot be compared in `status`/reconcile. Symlink *creation* (#63)
  works. Lifting this needs an agnos-side `lstat`/`readlink` surface.

## [1.0.2] - 2026-06-19

> Toolchain + vendored-stdlib refresh. No caller-visible surface
> change; the v1.0 contract (command surface, ADR 0001 manifest
> schema, ADR 0002 audit-trail format) stays frozen. Suite still
> **242 assertions / 66 groups**, all passing.

### Changed
- **Toolchain pin `6.0.1` → `6.2.24`** (`cyrius.cyml`
  `[package].cyrius`). The wrapper had already drifted to 6.2.24;
  this aligns the manifest pin with it.
- **Vendored `lib/` resynced to the 6.2.24 snapshot**
  (`cyrius lib sync`). Tracks the upstream stdlib carves: the
  former standalone `base64` / `csv` / `u128` / `bigint` / `toml` /
  `cyml` / `json` modules are now folded into the bundled **`bayan`**
  data-format module, and `matrix` / `linalg` / `math_advanced`
  into **`ganita`** (v6.1.25 carve). The nine now-folded standalone
  `lib/*.cyr` files were removed; `lib/bayan.cyr` + `lib/ganita.cyr`
  (and the new platform/tls split-outs) were added.
- **`src/manifest.cyr` include `lib/cyml.cyr` → `lib/bayan.cyr`.**
  The three `cyml_*` call sites (`cyml_parse_file_r`,
  `cyml_doc_header`, `cyml_doc_header_len`) are unchanged —
  `bayan`'s `_compat` section re-exports the old `cyml_*` names as
  thin shims over `bayan_cyml_*`, so the parser is byte-for-byte
  behaviourally identical. Release builds (`CYRIUS_DCE=1`) strip
  the unused `bayan` format bundles.
- **`cyrius.cyml` `[deps].stdlib`** — dropped `toml` + `cyml`
  (no longer stdlib modules), added `bayan`.

### Removed
- **`HapiSysno` enum + raw `syscall(N, …)` rename/fsync calls.**
  The stdlib `sys_rename` / `sys_fsync` / `sys_fdatasync` wrappers
  landed in cyrius 6.2.x (the coordinated removal flagged in
  [1.0.1]), so `src/manifest_write.cyr`, `src/cmd/adopt.cyr`, and
  `src/cmd/rollback.cyr` now call the named wrappers instead of
  the hand-rolled `HAPI_SYS_RENAME` (82) / `HAPI_SYS_FSYNC` (74)
  constants. Behaviour is unchanged on x86_64 (identical numbers)
  and now **arch-correct on aarch64** — the raw `82`/`74` literals
  were x86_64-only, whereas the wrappers route through the
  per-arch `renameat` / `fsync` syscalls. No caller-visible change.

## [1.0.1] - 2026-05-24

> 1.0.x-final hardening patch — closes the 1.0.x patch line. No
> caller-visible surface change; the v1.0 contract (command
> surface, ADR 0001 manifest schema, ADR 0002 audit-trail format)
> stays frozen. Internal syscall naming, one regression test, and
> the 1.0.x-final P(-1) audit pass.

### Changed
- **Syscall sites named (internal; no behavior change).** The bare
  `syscall(2/3, …)` probe calls in `src/fs_link.cyr` now use the
  stdlib `SYS_OPEN` / `SYS_CLOSE` constants, matching the existing
  `SYS_GETDENTS64` / `SYS_GETCWD` usage in the same file. The
  scattered `syscall(82, …)` rename calls (`manifest_write` /
  `adopt` / `rollback`) and the `syscall(74, …)` fsync call now
  resolve through one `HapiSysno` enum (`HAPI_SYS_RENAME` /
  `HAPI_SYS_FSYNC`) in `src/manifest_write.cyr`, marked for
  coordinated removal when the stdlib `sys_rename` / `sys_fsync`
  wrappers land (cyrius proposals 2026-05-17 / 2026-05-20).
  Codegen-identical — the constants resolve to the same numbers.

### Added
- Test: `sync: recovers after the audit trail is lost (drive-move
  scenario)` — locks the recovery semantics surfaced 2026-05-24
  (relative links survive a wiped `$XDG_STATE_HOME`, re-sync is a
  clean no-op, and the no-op sync does not rebuild the trail).
  Suite now **242 assertions / 66 groups**.
- `docs/audit/2026-05-24-audit.md` — the 1.0.x-final P(-1) re-walk
  pass; `docs/audit/README.md` establishes the audit-arc convention
  + index. New finding F-006 (audit trail lost on state-dir wipe)
  accepted as a boundary.
- Issues filed: `2026-05-24-no-arg-sync-bootstrap-recovery.md`
  (dogfood pressure on no-arg `sync` + the root-scan-over-trail
  design correction) and `2026-05-24-audit-trail-lost-on-state-dir-wipe.md`.

## [1.0.0]

### Breaking
- **Contract freeze.** The v1.0.0 release locks the contract
  for three surfaces. No signature changed in this release —
  the freeze IS the contract change.
  - **Command surface** — ten verbs (`link` / `unlink` /
    `adopt` / `sync` / `list` / `status` / `checkpoint` /
    `check` / `inspect` / `rollback`) plus four global flags
    (`--root`, `--dry-run`, `--backup-to`, `--force`,
    `--strict`). Arg shapes, exit codes, stdout / stderr line
    layouts are now contractual.
  - **`hapi.cyml` manifest schema** per ADR 0001 — frozen.
    `[package]` + `[[link]]` rows + the `ignore` glob list,
    with the validation rules in `src/manifest.cyr`.
  - **Audit-trail format** per ADR 0002 — frozen. JSONL with
    the required-field set, `sha1c:` canonical-hash prefix,
    additive-growth contract (readers MUST tolerate unknown
    fields). Pre-v1.0 `sha1:` raw-bytes hashes continue to be
    tolerated by readers.

  All five ADRs (0001 / 0002 / 0003 / 0004 / 0005) carry
  **Status: Frozen at v1.0.0 (2026-05-23)** as of this release.
  Post-v1.0 surface growth lives in the roadmap's *Deferred*
  section and any v1.x patch / minor must respect the freeze.

### Added
- `docs/development/release-notes/1.0.0.md` — the v1.0 release
  notes. Explains what "v1.0" means concretely (three frozen
  surfaces), walks the v1.0-criteria checklist, lists the
  post-v1.0-deferred items with rationale, and gives the
  v0.9.0 → v1.0.0 upgrade contract (no code changes required;
  v1.0 readers parse every v0.x trail).
- All five ADR Status lines updated to *Accepted — Frozen at
  v1.0.0 (2026-05-23)*; each ADR gains a one-paragraph
  freeze-contract note immediately under the Status header.

### Changed
- Roadmap *v1.0 criteria* checklist — every box ticked with
  the artifact that satisfies it.
- Roadmap M8 section — marked SHIPPED with the date.
- CLAUDE.md *CHANGELOG Format* paragraph clarified: manifest
  format and audit-trail format are now post-v1.0 frozen
  rather than "Breaking until v1.0."

### Filed
- Two open issues, both explicitly deferred post-v1.0 with
  rationale captured in the roadmap:
  - `issues/2026-05-20-sync-prune-deferred-row-removal-rotation.md`
    — row removal via full rotation works today; `--prune`
    surface is post-v1.0 if user demand earns it.
  - `issues/2026-05-23-cap-check-symlink-escape.md` — F-002
    MEDIUM from the audit pass. Lexical-only normalization at
    the cap-check; symlink-aware resolution lands with the
    kavach migration without breaking the `cap_check_root_r`
    API.

## [0.9.0]

### Security
- **F-001 [HIGH] — `--root` `..` bypass**, fixed.
  `cap_check_root_r` now lexically normalizes the resolved
  path (and `$HOME`, and each `HAPI_ALLOWED_ROOTS` entry)
  before the byte-prefix match. The pre-fix bypass —
  `--root /home/user/../etc/secret` passing as "within
  $HOME" while denoting `/home/etc/secret` — is rejected.
  New helper `fsl_lexical_normalize(path)` in
  `src/fs_link.cyr` collapses `.` and `..` segments without
  filesystem calls. Symbol-only fix; no caller signature
  changes.
- **F-003 [LOW] — backup-copy TOCTOU symlink race**, fixed.
  `hapi_backup_copy` now opens the source with
  `O_NOFOLLOW` (0x20000), so a `mv symlink → src` race
  between probe and copy fails with `ELOOP` instead of
  copying through the symlink. Defends the documented
  "snapshot of the original file's bytes" contract.
- **F-002 [MEDIUM] — `--root` symlink escape**, deferred.
  Lexical normalize does not resolve symlinks; the kavach
  migration owns the proper per-component resolution.
  Filed at `issues/2026-05-23-cap-check-symlink-escape.md`
  with reproduction + workaround.

### Added
- `docs/audit/2026-05-23-audit.md` — P(-1) hardening pass
  per CLAUDE.md Process step. Covers path traversal,
  symlink loops, TOCTOU, and capability boundary. Files
  three repairs (F-001 HIGH, F-003 LOW landed; F-002 MEDIUM
  deferred to kavach) and two accepted boundaries (F-004,
  F-005 per ADRs 0002 / 0004).
- `fsl_lexical_normalize(path)` in `src/fs_link.cyr` —
  pure-string `.` / `..` collapser. Used by
  `cap_check_root_r` and the `HAPI_ALLOWED_ROOTS` walker.
- Test suite grew 218 → 235 assertions (61 → 65 groups).
  New groups: lexical normalize, cap-check dotdot reject,
  allowlist normalization, backup-copy O_NOFOLLOW defense.
- `docs/benchmarks.md` — first M7 baseline. `sync` over a
  100-package / 350-link synthetic home: cold 72 ms (205 µs
  per link), warm 54 ms (154 µs per probe; 0 audit growth
  per the idempotency contract). Per-entry audit size 289
  bytes average — comfortably under the PIPE_BUF atomicity
  ceiling per ADR 0002. Reproduction harness inlined.

### Filed
- One open issue from the audit pass:
  `issues/2026-05-23-cap-check-symlink-escape.md` (F-002
  MEDIUM) — `--root` symlinked-component escape. Deferred
  to the kavach migration per ADR 0005.

## [0.8.0]

### Breaking
- Audit-trail `manifest_hash` prefix swap: `sha1:` →
  `sha1c:`. Writers emit only the canonical variant going
  forward; readers tolerate both prefixes during the
  M7 → M8 transition. Per ADR 0002, this is the prefix-swap
  Breaking the spec reserved at the format's introduction —
  the surrounding line format is unchanged. The
  `manifest_hash` field is diagnostic-only (rollback's
  identity check is `(pkg, target)`), so no consumer code
  needs to special-case the prefix; v0.x trails continue
  to read cleanly. Canonical form: `[package]` fields in
  fixed order (`name`, `version`, `description?`, `ignore?`),
  `[[link]]` rows sorted by `target` lex byte order, no
  comments, single blank line between sections, only `"` and
  `\` escaped in strings. Cosmetic edits (whitespace,
  comments, row reordering) now produce the same hash.

### Added
- `--backup-to <dir>` global flag — opt-in pre-`--force`
  snapshot. Accepted on **link, sync, adopt**; rejected with
  exit 2 on other verbs. Snapshots regular-file conflicts (not
  symlinks — symlinks point at content elsewhere). Filename
  shape: `<YYYYMMDD-HHMMSS>-<pkg>-<basename>`. Composes with
  `--dry-run` (destination printed; no snapshot written) and
  `--root`. Resolves
  `issues/2026-05-20-no-backup-to-flag-pre-hapi-bak-housekeeping.md`.
- `src/backup.cyr` — new module owning the process-wide
  `_hapi_backup_dir` flag (setter / getter mirror
  `cli.cyr::hapi_set_dry_run`), the `<ts>-<pkg>-<basename>`
  filename composer, and the byte-copy primitive
  (`hapi_backup_copy`).
- ADR 0002 additive field: `backup_path` (string, optional)
  on `link` and `adopt` entries. Per the ADR's growth
  contract, readers from v0.7.0 and earlier tolerate the new
  field without surfacing it. Audit reader (`hae_backup_path`)
  exposes the field on `HapiAuditEntry` for forward consumers.
- `docs/guides/backup-to.md` — cross-cutting guide for the
  new flag (semantics, filename layout, when to use it,
  composition with `--dry-run` / `--root`, audit-trail
  growth note).
- `hapi_mf_canonicalize(m, out, cap)` in `src/manifest.cyr`
  — re-serializes a parsed manifest to a fixed byte
  representation: `[package]` fields in fixed order,
  `[[link]]` rows sorted by `target`, no comments, single
  blank line between sections, only `"` and `\` escaped.
  Internal contract; bytes never surface to users.
- `audit_manifest_hash_raw(path)` in `src/audit.cyr` —
  legacy `sha1:` over raw file bytes, kept for trail-format
  diagnostics on pre-Unreleased entries. New entries use
  the canonical form by default.
- `docs/guides/status.md` — *Exit-1 is an assertion, not a
  predicate* section. Documents that `status`'s exit-1-on-drift
  is for CI / assertion use; points users at `link --dry-run`
  for the `&&`-chain pre-flight pattern. Resolves
  `issues/2026-05-20-status-exit-1-short-circuits-script-chains.md`
  (Tier-1). Zero code change — the surface already exists; the
  guide makes the contract legible.
- `docs/guides/upstream-drift.md` — new guide for the
  hyprland-class workflow where upstream rewrites its stock-
  config template every few releases. Codifies the 10-step
  audit + merge ritual, lists syntax-shift markers
  (wiki URLs, `autogenerated = 1` header, block-syntax
  migrations, new defaults), and specifies the dated
  tracking-note header that makes the next drift cycle
  cheaper. Resolves
  `issues/2026-05-20-upstream-stock-template-drift-pattern.md`
  (Tier-1). Tier-2 architecture note and Tier-3 speculative
  `hapi merge` verb remain post-v1.0 candidates.

### Changed
- `audit_manifest_hash(path)` now parses the manifest,
  canonicalizes it via `hapi_mf_canonicalize`, and hashes
  the canonical bytes. Returns `sha1c:` + 40 hex chars
  (was `sha1:` over raw file bytes at v0.7.0).
- ADR 0002 — gained a *Hash* table documenting both
  `sha1:` and `sha1c:` prefixes, the canonical re-serialization
  rules, and the reader-tolerates-both contract.
- `audit_format_link` / `audit_append_link_r` /
  `audit_format_adopt` / `audit_append_adopt_r` grew an
  optional last parameter `backup_path` (cstring, 0 when
  unset). Internal `_audit_format_link_op` emits the field
  only when the value is non-empty. `audit_format_unlink` /
  `audit_format_unadopt` signatures unchanged — those ops
  never carry a backup.
- Test suite: 194 → 218 assertions (52 → 61 groups). Five
  new groups cover the compose-path filename layout, the
  link --force snapshot end-to-end (audit + on-disk read-back),
  symlink-conflict skip, dry-run no-write invariant, and the
  adopt-before-rename snapshot. Four new canonicalization
  groups cover the `sha1c:` prefix, comment/whitespace
  collisions, row-reorder collisions, and value-change
  divergence. The existing `test_audit_format_link` gained
  two assertions for the optional-field presence/absence
  semantics.
- `link.md`, `adopt.md`, `sync.md`, `dry-run.md` each gained
  a `--backup-to` section pointing at the new guide.

### Filed
- Three M7 dogfood-papercut issues archived to
  `docs/development/issues/archived/`: status-exit-1
  (Tier-1 doc note), upstream-drift (Tier-1 new guide),
  no-backup-to (full `--backup-to <dir>` flag).

## [0.7.0]

### Added
- ADR 0005: capability-bounded roots. `$HOME` is the
  implicit default; `--root <path>` opens a non-default
  scope gated by `cap_check_root_r`. The check is an env-var
  allowlist (`HAPI_ALLOWED_ROOTS`, colon-separated, absolute
  paths only) as the explicit stopgap until kavach lands;
  the API contract `cap_check_root_r(path) -> Result`
  survives the kavach migration unchanged. Path-within
  matcher splits on `/` components so `/etc/myproject`
  never matches `/etc/myprojectextra`.
- `src/cap.cyr` — owns `cap_check_root_r`, the path-within
  matcher, and test hooks `cap_set_home` / `cap_set_allowlist`.
- `src/cli.cyr` — owns the process-wide `_hapi_dry_run`
  flag with setter / getter. Every mutating cmd checks the
  flag before its first syscall + audit write.
- `--root <path>` accepted on **link, adopt, sync, status,
  list**. Cap-check fires before dispatch; on denial, the
  binary exits 1 with `hapi: --root path is not in
  HAPI_ALLOWED_ROOTS (and is not within $HOME)`.
- `--dry-run` accepted on **link, unlink, adopt, sync,
  rollback, checkpoint**. Each verb runs its planning
  phase, prints the would-do lines suffixed `(dry-run)`,
  and skips every syscall + audit write. Exit codes match
  the real run.
- Per-verb arg parsing now rejects unrecognized `--flag`
  args with exit 2 + `hapi: unexpected flag for `<verb>`:
  <flag>`. Previously an unknown flag was silently
  swallowed as a positional arg.
- `docs/guides/capability.md` — user-facing guide for
  `--root` + the env-var allowlist.
- `docs/guides/dry-run.md` — user-facing guide for the
  composable preview flag.

### Changed
- `hapi --version` reports 0.7.0; help text grew a
  **global flags** section listing `--root` and `--dry-run`
  with their verb scopes.
- Test suite grew from 163 → 194 assertions (41 → 52
  groups) — cap × 4, dry-run × 6 (one per mutating verb),
  plus the M6 unit coverage of the path-within matcher.
- `HapiMfError` enum gained `HapiMfUnknownSection` and
  `HapiMfUnknownKey` (used by `check --strict`, shipped in
  v0.6.0 — listed here for completeness; the variants
  belong to the M5 work but the M6 dispatcher rewrite
  surfaced them in shared error-message tables).
- State.md and roadmap.md updated: M6 retired, M7
  (dogfood + harden) surfaced as Next.

## [0.6.0]

### Added
- `hapi checkpoint` — appends an `op:rollback-marker` entry
  to the audit trail. User-facing surface for the marker
  machinery that shipped in M3 (audit-writer + rollback's
  walk-to-marker logic). `src/cmd/checkpoint.cyr`.
- `hapi status <pkg>` — read-only drift classifier. Walks
  the manifest's [[link]] rows, probes each target, prints
  one of `OK` / `MISSING` / `WRONG` / `FILE` / `DIR` /
  `ERROR`. No audit writes; no filesystem mutation. Exit 0
  when clean, 1 on any drift. `src/cmd/status.cyr`.
- `hapi list` — walks the audit trail, prints unique
  packages in first-seen order with their live-link count.
  Reduction treats `link`/`adopt` as creators and
  `unlink`/`unadopt` as removers (generalizes the unlink
  command's per-target last-write-wins logic). Empty trail
  is not an error. `src/cmd/list.cyr`.
- `hapi check <pkg> [--strict]` — sibling of `inspect` with
  an opt-in `--strict` mode. Strict rejects any `[section]`
  other than `[package]` / `[[link]]`, and any unknown key
  inside the known sections. The default parser stays
  lenient per ADR 0001's additive-growth headroom; the
  strict mode is the CI / lint surface. New
  `HapiMfUnknownSection` and `HapiMfUnknownKey` error
  variants in `src/manifest.cyr`, plus a module-level
  `_hapi_mf_strict` flag that `cmd_check` sets/clears
  around the parse call. `src/cmd/check.cyr`.
- `hapi sync <pkg>` — re-apply a package's manifest
  idempotently. At v0.6.0 this is `cmd_link` without
  `--force`; the verb is the user-facing intent. Acceptance
  test passes: `sync` on a clean tree produces zero new
  audit entries. `src/cmd/sync.cyr`.
- Per-command guides: `docs/guides/checkpoint.md`,
  `status.md`, `list.md`, `check.md`, `sync.md`.

### Changed
- `hapi --version` reports 0.6.0; help text lists every
  new verb.
- Test suite grew from 127 → 163 assertions (29 → 41
  groups) — checkpoint × 1, status × 4, list × 3,
  strict-mode parser × 4, check × 1, sync × 2.
- Roadmap M5 line in [`state.md`](docs/development/state.md)
  retired; "Next" now points at M6 (`--root` capability
  gate, `--dry-run`).
- A no-arg `hapi sync` (sync every package in the trail) is
  deferred from M5 — the audit format doesn't carry a
  manifest path, so package-dir recovery would need either
  a tree-walk heuristic or an additive trail field. Filed
  as a post-M5 candidate in state.md's source section.

## [0.5.0]

### Added
- ADR 0004: `hapi adopt` op semantics. Two positional CLI
  args, atomic single-entry audit record (`op:adopt`), append
  `[[link]]` row before `---` body separator, three-step
  conditional rollback (remove symlink → move file back →
  remove manifest row).
- `src/manifest_write.cyr` — append + remove `[[link]]` rows
  in `hapi.cyml`. Atomic via `tmp+rename` (no corruption on
  crash). Append preserves comments, user formatting, and
  the markdown body. Remove strips matching block + leading
  blank lines.
- `src/cmd/adopt.cyr` — `hapi adopt <file> <pkg>`. Probes,
  parses, refuses on duplicate / wrong-type targets, renames
  file into package, creates relative symlink, appends
  manifest row, writes audit entry. Source name is target's
  basename with leading `.` stripped.
- `src/audit.cyr` — `audit_append_adopt_r` and
  `audit_append_unadopt_r` (the rollback-reverse op).
- `src/cmd/rollback.cyr` — handles `op:adopt` entries with
  the three-step conditional reversal. Ignores `op:unadopt`
  (forward-replay records, not re-reversible).
- `hapi adopt <file> <pkg>` wired into the dispatcher.
- `docs/guides/adopt.md`.
- Tests: M4 acceptance (adopt happy path), every refusal
  case (symlink target / directory target / absent target /
  duplicate manifest row), manifest_write append + remove,
  rollback-of-adopt three-step reversal. 127 assertions
  total (was 100 in v0.4.0).

### Changed
- `hapi --version` reports 0.5.0; help text lists `adopt`.
- Roadmap updated — deferred items from M1–M3 are now
  anchored to specific milestones (M5 picks up
  `hapi checkpoint` and `hapi check --strict`; M7 picks up
  the manifest-hash canonicalization migration) or
  explicitly listed under a new "Deferred during M1–M3"
  section in Out-of-scope with ADR citations.

### Filed upstream
- Proposal at
  `cyrius/docs/development/proposals/2026-05-20-syscalls-fsync-stdlib.md`
  for `sys_fsync` / `sys_fdatasync` stdlib wrappers. Hapi
  currently calls `syscall(74, fd)` directly in
  `_hmw_write_atomic`; the magic number is the
  cross-arch-mismatch hazard the bare-name wrappers exist
  to prevent. Companion to the 2026-05-17 *at()-family
  proposal (`sys_rename` lives there). Targets the v6.x
  stdlib-syscall expansion arc.

## [0.4.0]

### Added
- `src/audit_reader.cyr` — JSONL reader. Hand-rolled scanner
  scoped to the ADR 0002 field set; unescapes `\"`, `\\`,
  `\n`, `\r`, `\t`, `\uXXXX` (writer only emits `\u00XX`).
  Drops malformed and torn-final lines silently per the
  ADR's crash-safety contract.
- `src/audit.cyr` — `audit_append_unlink_r` and
  `audit_append_rollback_marker_r`. `audit_format_link`
  and `audit_format_unlink` share a common formatter.
- `src/cmd/unlink.cyr` — `hapi unlink <pkg>`. Reads trail,
  identifies live links for the package (link entries not
  superseded by a later unlink), removes each only if the
  current symlink matches what hapi wrote. Refuses
  user-mutated entries (exit 1), keeps processing the rest.
- `src/cmd/rollback.cyr` — `hapi rollback`. Walks trail
  backward to the most recent `op:rollback-marker`,
  conditionally reverses every entry in between. Idempotent
  by construction — re-running produces the same end state.
- `hapi unlink <pkg>` and `hapi rollback` wired into the
  dispatcher.
- `docs/guides/unlink.md` and `docs/guides/rollback.md`.
- Tests: M3 acceptance (link → unlink → no residue, trail
  records both ops), user-mutation refusal, audit-reader
  round-trip, torn-line and malformed-line drops, rollback
  through link/unlink/link → clean slate, rollback
  idempotency, rollback stops at marker. 100 assertions
  total (was 69 in v0.3.0).

### Changed
- `hapi --version` reports 0.4.0; help text lists `unlink`
  and `rollback`.
- Refactored hand-counted `print(lit, N)` calls in
  `src/cmd/inspect.cyr` and `src/cmd/link.cyr` to use
  strlen-via-helpers (`_hi_puts` / `_hi_eputs` /
  `_hlnk_puts` / `_hlnk_eputs`). An off-by-one in the
  directory-blocked message at v0.3.0 leaked an adjacent
  rodata byte; the helpers eliminate the whole class of bug.

### Fixed
- Directory-blocked error message no longer prints a stray
  leading space character (was rendering with three leading
  spaces, now two — the byte count for the literal was off
  by one in v0.3.0).

## [0.3.0]

### Added
- ADR 0002: audit-trail format. JSONL at
  `$XDG_STATE_HOME/hapi/audit.jsonl`, append-only, one JSON
  object per line, fields ordered for canonical serialization.
  Format is **Breaking** for hash semantics (canonicalization
  switch reserved as `sha1:` → `sha1c:` for v1.0); everything
  else is additive.
- ADR 0003: symlink target shape. Relative-from-the-link's-
  parent-directory — keeps dotfile repos portable across
  machines and clone paths. Matches GNU stow convention.
- `src/audit.cyr` — audit-trail writer. JSON escaping for
  control bytes / `\` / `"`. `audit_append_link_r` does a
  single flock'd append per entry; entries are well under
  PIPE_BUF so POSIX atomicity holds.
- `src/fs_link.cyr` — symlink primitives. `link_probe` (one
  `readlink(2)` + a directory probe to split FILE / DIRECTORY),
  `fsl_compute_relative` (longest-common-prefix + `..` prepend),
  `link_create` (mkdir -p on parent + symlink).
- `src/cmd/link.cyr` — `hapi link <pkg> [--force]`. Pre-flights
  every target, refuses on any conflict without `--force`, then
  creates the new links and audits each write. `--force`
  replaces a symlink-to-elsewhere or a regular file; never a
  directory.
- `hapi link <package>` wired into the dispatcher.
- `docs/guides/link.md` — semantics, flags, exit codes, audit
  trail pointer.
- Tests: M2 acceptance (3-link package, re-run is no-op),
  conflict refusal, `--force` replace, `--force` refuses
  directory, audit JSON shape, JSON escaping, link_probe
  classification, relative-path computation. 69 assertions
  total (was 36 in v0.2.0).

### Changed
- `[deps].stdlib` gained `sha1` (manifest hashing) and
  `chrono` (ISO 8601 audit timestamps).
- `hapi --version` now reports 0.3.0; help text lists `link`.

## [0.2.0]

### Added
- ADR 0001: `hapi.cyml` manifest schema. `[package]` table for
  metadata (`name`, `version`, `description`, `ignore`); one or
  more `[[link]]` rows for the symlinks themselves. Single-entry
  CYML — TOML header above `---`, optional markdown body below.
  Schema is **Breaking** until v1.0; after v1.0 it freezes.
- `src/manifest.cyr` — manifest parser. Validates name/version
  presence, `[[link]]` source/target presence, duplicate-target
  rejection, and `..` path-segment rejection in both source and
  target. Filesystem checks (source exists, target writable,
  capability scope) deferred to M2.
- `hapi inspect <path>` — read a manifest and print the parsed
  interpretation. Read-only; never touches the scoped root.
  Accepts a package directory or a direct `*.cyml` path.
- `hapi --version` / `-v`, `hapi --help` / `-h` — surface the
  CLI dispatcher's basic shape from day one.
- `docs/examples/dotfiles-zsh/` — canonical 3-file example
  package; drives the M1 acceptance test.
- `docs/guides/inspect.md` — command guide.
- Test suite: 36 assertions across happy path, validation
  errors, path-traversal, comments/blanks, on-disk parse, and
  missing-file error.

### Changed
- `cyrius.cyml` toolchain pin bumped from 6.0.0 to 6.0.1.
- `[deps].stdlib` gained `args`, `fs`, `result`, `toml`, `cyml`,
  `slice` for the manifest parser and dispatcher.

## [0.1.0]

### Added
- Initial project scaffold
