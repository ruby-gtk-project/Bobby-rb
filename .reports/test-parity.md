# Test parity — Bobby

Reconfirmed and re-derived this round against current `HEAD`. The previous
version of this report (port @ `9a3ce26`) is superseded; it predated
`spec/bobby/sqlite/row_spec.rb`, which lands the port's bijection claim false.
Re-run live again this round at `ada9290` (one commit past `314c519`, Flatpak
packaging only — `git diff 314c519 HEAD -- spec/ test/` is empty, so nothing
below moved):

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `ada9290` (HEAD) |
| Upstream `#[test]` functions | **1** |
| Upstream source files with any test | **1 of 34** |
| Port spec files | **2** — `spec/bobby/sqlite/affinity_spec.rb`, `spec/bobby/sqlite/row_spec.rb` |
| Port examples (live run) | **36 examples, 0 failures**, `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` |
| Drive (live run) | **474 of 474 checks passed**, `DRIVE OK` |
| Gaps in the bijection | **1 — new finding this round, see below** |

## Census

```
$ test-census.sh <upstream>
src/bobby/tests/sqlite/test_sqlite_affinity.rs	test_sqlite_affinity_to_type_string	12
```

Cross-checked: `Cargo.toml` declares no `[[test]]` target and there is no
`tests/` directory, so the whole suite is the inline `#[cfg(test)] pub mod
tests` routed through `src/bobby/tests/mod.rs`, which names exactly one
module, which names exactly one `#[test]` function, asserting six `assert_eq!`
calls (NUMERIC, INTEGER, REAL, TEXT, BLOB, NULL). `grep -rnE
'#\[(test|tokio::test)\]' src/` returns that one hit and no other. The census
is complete: **upstream has one test, period.**

```
$ test-census.sh <port>
spec/bobby/sqlite/affinity_spec.rb   30 examples
spec/bobby/sqlite/row_spec.rb         6 examples
test/drive_bobby.rb                 474 checks over 84 steps
```

## The ledger

### Suite: sqlite/affinity (1 upstream test)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `src/bobby/tests/sqlite/test_sqlite_affinity.rs#test_sqlite_affinity_to_type_string` | every `Affinity` variant reports its own SQLite type name, in order: NUMERIC, INTEGER, REAL, TEXT, BLOB, NULL | `spec/bobby/sqlite/affinity_spec.rb` → `#type_string names every affinity` | ported, 1:1 |

`affinity_spec.rb`'s other 29 examples (`.parse`, `.from_value`, `#to_s`,
`#dimmed?`, `#tooltip`) are the port's own, exercising `Affinity` methods
upstream never wrote a test against — they stay in **Extra**, outside the
count, same as prior rounds.

### Finding: `row_spec.rb` is six port tests with no upstream counterpart

`spec/bobby/sqlite/row_spec.rb` landed in `9a4be48` ("Port upstream's paged
`DatabaseCacheModel` as a lazy `Gio::ListModel`"), after the previous
test-parity audit (port @ `9a3ce26`) was written. Its own header comment is
explicit about what it is testing: `Row.page` is **"the port's own second
query"** — it does not exist in `src/bobby/sqlite/row.rs` at all. Upstream has
no test file for `sqlite/row.rs`, paged or otherwise; `test_sqlite_affinity.rs`
is upstream's only test file, full stop.

So the census now has six Ruby examples that:

- test a method (`Row.page`) upstream does not have,
- in a file upstream never wrote a test for,
- with zero upstream test to map to on either side of the join.

Per the skill, a bijection means *every port test is named by exactly one
upstream test*. These six are named by none. The previous report's line
"the bijection holds at 1/1" is no longer true the moment `row_spec.rb`
existed, and nothing updated it. **This is gap T-01: the test-parity report
was carried forward as green across a commit that broke its own central
claim.**

This is not a claim that the six tests are bad — `Row.page` is real,
necessary behaviour (`Sqlite::Cache`'s lazy paging depends on it, and it is
driven live by `test/drive_bobby.rb`'s big-table steps too) and PORTING.md's
own "Deliberate divergences" section names the rowid/offset split honestly.
The defect is narrower and sharper than "six extra tests exist": **it is that
the parity report kept asserting a 1:1 bijection after a commit made that
false, and nobody re-ran this skill to catch it.** That is exactly the failure
mode `accountability-ensurance` exists to catch, and it is cross-filed there.

## Extra

Everything below is outside the count and stays outside it.

- `spec/bobby/sqlite/affinity_spec.rb` — 29 further examples beyond the one
  ported test: 7 on `.parse` (declared-type rules, including the
  INT-before-FLOA ordering `FLOATING POINT` turns on), 9 on `.from_value` (six
  reading values out of a real in-memory database), 4 on `#to_s`, 5 on the
  REAL-rendering `#to_s` sub-block, 1 on `#dimmed?`, 3 on `#tooltip`.
- `spec/bobby/sqlite/row_spec.rb` — 6 examples on `Row.page` and `Row.all`,
  discussed above.
- `test/drive_bobby.rb` — 474 checks over 84 steps driving the real
  application headlessly: the three window states, all eleven actions, the
  four dialogs, both menus, the switcher, the preferences round trip, the
  CLI, the log, the clipboard, multi-window handling, the close path, and (new
  since the last audit) the toast title/timeout/dismiss/cutoff.

## What this means

Upstream pinned **one** property, in one class, out of 34 source files.
**The port therefore inherits essentially no safety net from upstream.**
33 of 34 upstream source files have never had a test written against them by
anyone, upstream or port, and the one property that was pinned is a six-way
string lookup.

The port's own ~509 extra assertions (35 spec examples + 474 drive checks) are
where the real evidence is, and FINDINGS.md documents five defects they found
that reading alone did not. They are also where the remaining blind spots are.
Measured against the current component audit:

| Not asserted by anything | Consequence |
|---|---|
| a drop that actually opens a database via a synthesised `Gdk::FileList`; the file chooser's async finish path | open gap **C-23**, a recorded binding limitation |
| `Settings::CHOICES` against the schema's `<choices>` | the port's hard-coded copy can drift from the schema where upstream's cannot — not separately gap-numbered, worth watching |
| Flatpak-specific branches (`App.flatpak?`, `PREFIX = '/app'`) | a manifest now exists (`ada9290`) but has never been built with `flatpak-builder`, so these branches still have never executed — reopened this round as **C-24** in `.reports/component-parity.md`, since PORTING.md had marked C-12/13/14 closed on the manifest's existence alone |

Coverage by file, for the record: **2 of the port's 41 `lib/` files have a
spec** (`sqlite/affinity.rb`, `sqlite/row.rb`). `application.rb`, `window.rb`,
all six widgets, all four dialogs, all ten actions, `cli.rb`, `log.rb`,
`app.rb`, `preflight.rb`, `icons.rb`, `settings.rb`, `util.rb` and four of the
remaining five `sqlite/` files have none. The drive exercises most of them at
runtime; nothing exercises them per unit.

## Finding: the suite now runs from the command the dev shell prints — C-21 is closed

Re-run live this round:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
36 examples, 0 failures
```

`spec/spec_helper.rb` now wraps the `kettle/test/rspec` require in the same
`rescue LoadError` pattern the `kettle-soup-cover` require above it already
had, re-raising anything whose message does not mention kettle. That is a real
fix, not a workaround that discards `.rspec`/`spec_helper.rb` the way the
previous round's "25 examples" figure did. **C-21 is closed**, matching
PORTING.md's own ledger.

The root bundle still does not resolve on Ruby 3.4 (`kettle-family >= 1.3.29`
requires Ruby `>= 4.0.0`), so `bundle exec rspec` at the repo root still
fails; that is recorded in FINDINGS.md under *About the bindings* and is not
re-litigated here, since the devShell path — the one actually printed and
actually run — now works.

## Rules check

- Counts equal, upstream to port's *ported* set: 1 = 1 ✓
- Bijection over the full port suite: **✗** — 6 of 36 examples (`row_spec.rb`)
  have no upstream test to map to (gap **T-01**)
- Same property asserted, same inputs, same order, for the one pair that maps: ✓
- The suite passes under its own printed test target: ✓ (reconfirmed live,
  36/36) — **C-21 closed**
- The drive passes: ✓ (reconfirmed live, 474/474) — **DRIVE OK**

**Verdict: the single upstream test is ported 1:1 and the suite is green and
runnable by its own declared command, closing C-21. Test parity as a whole is
not proven, because the port's suite contains six examples the upstream
census cannot account for, and the prior audit's "bijection holds at 1/1"
claim survived a commit that made it false. One new gap, T-01 — a reporting
gap, not a runtime one.**
