# Test parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `28bb3a5eec99ec3b5543f00e902cf10d00ba0fe9` |
| Upstream tests | **1** |
| Ported | **1** |
| Gaps | **0** in the bijection |
| Test command | **none that works** — see the finding below |

## Census

```
$ test-census.sh <upstream>
src/bobby/tests/sqlite/test_sqlite_affinity.rs	test_sqlite_affinity_to_type_string	12
```

One row. Cross-checked against the build file as the skill requires:
`Cargo.toml` declares no `[[test]]` target and there is no `tests/` directory,
so the whole suite is the inline `#[cfg(test)] pub mod tests` declared at
`src/bobby/mod.rs:19` and routed through `src/bobby/tests/mod.rs`, which names
exactly one module. `grep -rn '#\[test\]\|#\[tokio::test\]\|#\[gtk::test\]'`
over `src/` returns the same single hit. The census is complete.

```
$ test-census.sh <port>
19 rows, all in spec/bobby/sqlite/affinity_spec.rb
```

Two of those rows read `shows a blob` — the scanner truncates at the
apostrophe in `shows a blob's size` (line 89) and `shows a blob's preview`
(line 120). Nineteen distinct examples, keyed by `file#identifier@line`.

## The ledger

### Suite: sqlite/affinity (1 test)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `src/bobby/tests/sqlite/test_sqlite_affinity.rs#test_sqlite_affinity_to_type_string` | every `Affinity` variant reports its own SQLite type name: NUMERIC, INTEGER, REAL, TEXT, BLOB, NULL | `spec/bobby/sqlite/affinity_spec.rb#names every affinity` (line 11) | ported |

The Ruby example asserts the same six names in the same order against the same
six variants. The mapping is a bijection: 1 → 1.

## Extra

Eighteen examples written for the port with no upstream counterpart. They are
outside the count and stay outside it.

- `spec/bobby/sqlite/affinity_spec.rb` — 7 on `.parse` (the declared-type rules, including the INT-before-FLOA ordering that `FLOATING POINT` turns on), 3 on `.from_value`, 4 on `#to_s`, 1 on `#dimmed?`, 3 on `#tooltip`.

## What this means

Upstream pinned one property. **The port therefore inherits essentially no
safety net** — 33 of the upstream project's 34 source files have never had a
test written against them by anybody, and the port's 19 examples all sit in
one class. Parity is met, and parity being met is not reassurance. Two defects
that this report's sibling found by *running* the app would have been caught
by a test in either project, and were caught by neither:

- `Affinity.from_value` never produces a `BLOB`, because the `sqlite3` gem returns blobs as plain `ASCII-8BIT` strings and the `when SQLite3::Blob` arm is unreachable from any read path. `affinity_spec.rb:72` and `:120` pass only because they hand-construct `SQLite3::Blob.new`, which the database layer never does. **A test that read a blob back out of a real table instead of constructing one would fail today.**
- `Util.copy_to_clipboard` calls a `Gdk::Clipboard#set_text` that does not exist. No example touches `lib/bobby/util.rb` at all.

Coverage by file, for the record: 1 of the port's 31 `lib/` files has a spec.
`application.rb`, `window.rb`, all six widgets, all four dialogs, all ten
actions, `cli.rb`, `log.rb`, `app.rb`, `settings.rb`, `util.rb` and five of
the six `sqlite/` files have none.

## Finding: there is no working test target, so the fourth proof condition fails

The skill's Step 4 requires that "the port's suite passes under its own test
target". The port declares several and none of them runs:

| Command | Result |
|---|---|
| `bundle exec rake test` | `can't find executable rake for gem rake. rake is not currently included in the bundle` |
| `bundle exec rake spec` | same |
| `bundle exec rspec` | `bundler: command not found: rspec` |
| `rspec` | not installed |
| `rspec --options /dev/null --format progress --require sqlite3 --default-path spec -I lib` | the command `.github/workflows/tests.yml` runs — it bypasses `.rspec` and `spec/spec_helper.rb` entirely |

The root `Gemfile` does not resolve: it depends on `kettle-family >= 1.3.29`,
which requires Ruby >= 4.0.0, while the gemspec sets
`required_ruby_version >= 3.4`. There is no `Gemfile.lock`. So `.rspec`'s
`--require spec_helper` is dead — `spec/spec_helper.rb` loads
`kettle/test/rspec` and `kettle-soup-cover` from that same unresolvable graph —
and the only command that works is one that skips both files.

`FINDINGS.md` records the lockfile problem honestly. What it does not say is
the consequence: the port ships a `Rakefile` with a `spec` task, an `.rspec`
and a `spec_helper.rb` that together describe a test target nobody can invoke,
and the real one is a 70-character incantation that exists only inside a CI
yaml. The suite was not run during this audit, because it cannot be run from
the repository as checked out. `19 examples, 0 failures` in `FINDINGS.md` is a
claim this report could not reproduce.

The port's own devShell would be the obvious place to fix this, and it is
where the audit did get GTK running — but `nix/Gemfile` lists only `adwaita`
and `gtk4`, with neither `sqlite3` nor `rspec`, so the suite cannot run there
either.

## Rules check

- Counts equal: 1 = 1 ✓
- Bijection: 1 → 1, no merges, no splits ✓
- Same property asserted: ✓
- Every ledger row has a named port test: ✓
- The named test exists in the port tree: ✓ (`spec/bobby/sqlite/affinity_spec.rb:11`)
- **The suite passes under its own test target: ✗** — there is no such target

**Verdict: the bijection holds at 1/1; the proof does not, because the fourth
condition cannot be met.**
