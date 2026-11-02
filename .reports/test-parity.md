# Test parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `9a3ce26f5edc81fdd0614ab6e3523ff09305463d` |
| Upstream tests | **1** |
| Ported | **1** |
| Gaps in the bijection | **0** |
| Test command | **none of the declared ones runs** — including the one the dev shell prints. See the finding. |
| Suite executed this round | yes, under a hand-built invocation: **25 examples, 0 failures** |
| Drive executed this round | yes: **428 of 428 checks passed**, `DRIVE OK`, exit 0 |

## Census

```
$ test-census.sh <upstream>
src/bobby/tests/sqlite/test_sqlite_affinity.rs	test_sqlite_affinity_to_type_string	12
```

One row. Cross-checked against the build file as the skill requires:
`Cargo.toml` declares no `[[test]]` target and there is no `tests/` directory,
so the whole suite is the inline `#[cfg(test)] pub mod tests` at
`src/bobby/mod.rs:19` routed through `src/bobby/tests/mod.rs`, which names
exactly one module. `meson.build:47` registers a single `test('cargo_test', …
args: ['test'])`, which runs that one case.
`grep -rnE '#\[(test|tokio::test|gtk::test)\]'` over `src/` returns the same
single hit. The census is complete.

```
$ test-census.sh <port>
25 rows  spec/bobby/sqlite/affinity_spec.rb
476 rows test/drive_bobby.rb
```

**The assertion unit of `test/drive_bobby.rb` is `check`, not `step`.**
`test/gtk_driver.rb:83-84` is where `@checks` is incremented; `step` only
groups and is counted in `@steps`. The census collects both, so its 476 is
neither figure — the driver's own counter reports **84 steps and 428 checks**,
and 428 is the number this report uses. 48 of the census's rows are `step`
names and the rest are `check` descriptions, with the interpolated ones
missing, which is the shape the skill warns about.

Duplicate identifiers: `cut -f2 port-tests.tsv | sort | uniq -d` returns
several in the drive, so drive rows are keyed `file#identifier@line`. The spec
file has none.

## The ledger

### Suite: sqlite/affinity (1 test)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `src/bobby/tests/sqlite/test_sqlite_affinity.rs#test_sqlite_affinity_to_type_string` | every `Affinity` variant reports its own SQLite type name, in order: NUMERIC, INTEGER, REAL, TEXT, BLOB, NULL | `spec/bobby/sqlite/affinity_spec.rb#names every affinity` (line 12) | ported |

The Ruby example asserts the same six names in the same order against the same
six variants. The mapping is a bijection, 1 → 1, with no merges and no splits.

## Extra

Everything below is outside the count and stays outside it. Parity is a floor
upstream set; none of this is parity work.

- `spec/bobby/sqlite/affinity_spec.rb` — 24 further examples: 7 on `.parse` (the declared-type rules, including the INT-before-FLOA ordering that `FLOATING POINT` turns on), 9 on `.from_value` (six of them reading their values out of a real in-memory database rather than constructing a `SQLite3::Blob`, which is why the earlier versions passed while the blob feature was broken), 4 on `#to_s`, 1 on `#dimmed?`, 3 on `#tooltip`.
- `test/drive_bobby.rb` — 428 checks over 84 steps driving the real application headlessly: the three window states, all eleven actions, the four dialogs, both menus, the switcher, the preferences round trip, the CLI, the log, the clipboard, multi-window handling, the close path.

## What this means

Upstream pinned **one** property, in one class, out of 34 source files.

**The port therefore inherits essentially no safety net.** Parity is met at
1/1, and parity being met here is not reassurance about anything: 33 of
upstream's 34 files have never had a test written against them by anybody, and
the one property that was pinned is a six-way string lookup. Saying so plainly
is the finding; leaving it implied is how a 1/1 report gets read as a pass.

The port's own 453 extra assertions are where the actual evidence is, and they
were what found the last seven defects. They are also where the remaining
blind spots are. Measured against this round's component audit:

| Not asserted by any of the 453 | Consequence |
|---|---|
| any REAL cell's rendered text | gap **C-17** — `1.0` where upstream renders `1` — survived two audits |
| the toast title, its timeout, `dismiss_all`, or the 96-unit cutoff | gaps **C-18**, **C-19**, **C-20** |
| `Settings::CHOICES` against the schema's `<choices>` | the port's hard-coded copy can drift from the schema where upstream's cannot |
| a drop that actually opens a database; the file chooser | gap **C-23**, a binding limitation, recorded |

Coverage by file, for the record: **1 of the port's 47 `lib/` files has a
spec.** `application.rb`, `window.rb`, all six widgets, all four dialogs, all
ten actions, `cli.rb`, `log.rb`, `app.rb`, `preflight.rb`, `icons.rb`,
`settings.rb`, `util.rb` and five of the six `sqlite/` files have none. The
drive exercises most of them at runtime; nothing exercises them per unit.

## Finding: the suite runs, but not by any command the project declares

The skill's Step 4 requires that "the port's suite passes under its own test
target". The port declares four and **none of them works** — including, this
round, the one the dev shell itself prints:

| Command | Result |
|---|---|
| the dev shell banner's own line: `nix develop --command ruby -e 'require "rspec/core"; … "--require", "spec_helper", "spec"'` | `LoadError: cannot load such file -- kettle/test/rspec` at `spec/spec_helper.rb:23` → **0 examples, 2 errors outside of examples** |
| `nix develop --command bundle exec rspec` | bundler aborts; the root bundle does not resolve |
| the same without `--require spec_helper` | still fails — `.rspec` supplies `--require spec_helper` anyway → **0 examples, 1 error** |
| `nix develop --command ruby -e '… ["--options","/dev/null","--format","progress","spec"]'` | **25 examples, 0 failures** |

Only the last works, and it works by discarding `.rspec` and `spec_helper.rb`
entirely. That is a worse state than the previous audit found, not a better
one: `nix/Gemfile` gained `sqlite3` in `ca5cafa` and the flake's shell hook
gained a printed spec command, so the project now *advertises* a test command
that fails on the first line of the file it loads.

The chain is:

- `.rspec:4` is `--require spec_helper`, so every invocation loads `spec/spec_helper.rb`;
- `spec/spec_helper.rb:23` requires `kettle/test/rspec`, from the kettle-dev development bundle;
- `nix/Gemfile` carries the gemspec's runtime gems only — `adwaita`, `gtk4`, `sqlite3` — so the devShell has no `kettle-test`;
- the root `Gemfile` would have it, and does not resolve: `kettle-family >= 1.3.29` declares Ruby >= 4.0.0 against the gemspec's `required_ruby_version >= 3.4`, and there is no root `Gemfile.lock` (`git ls-files | grep Gemfile.lock` → only `nix/Gemfile.lock`);
- `.github/workflows/tests.yml` sidesteps all of it with `gem install` and an explicit `--options` override.

So the port ships a `Rakefile` with a `spec` task, an `.rspec`, a
`spec_helper.rb` and a dev-shell banner that between them describe a test
target nobody can invoke, and the real one is an incantation that lives in a CI
yaml and in this report. **That is gap C-21.** `FINDINGS.md` records the
lockfile problem honestly and does not record this consequence.

The 25 examples do pass, and that was verified in this round from a cold shell.
The claim being withheld is not "the suite is broken" — it is "the suite can be
run the way the project says to run it".

## Rules check

- Counts equal: 1 = 1 ✓
- Bijection: 1 → 1, no merges, no splits ✓
- Same property asserted, same inputs, same order ✓
- Every ledger row has a named port test ✓
- The named test exists by that name in the port tree ✓ (`spec/bobby/sqlite/affinity_spec.rb:12`)
- The suite passes under its **own** test target: **✗** — no declared target runs
- The suite passes at all: ✓ — 25/25, under an invocation built by hand

**Verdict: the bijection holds at 1/1 and the suite is green at 25/25, but the
fourth proof condition fails, so test parity is not proven. One open gap,
C-21.**
