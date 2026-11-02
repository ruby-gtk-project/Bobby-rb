# Test parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe` |
| Port | `ruby` branch |
| Upstream tests | 1 |
| Ported | 1 |
| Gaps | **1 — the suite cannot be run** |
| Suite status | **not green: not executed** |

## Census

Upstream, via `test-census.sh`:

```
src/bobby/tests/sqlite/test_sqlite_affinity.rs	test_sqlite_affinity_to_type_string	12
```

One test function, six assertions. Cross-checked against the build file:
`src/bobby/mod.rs:16-17` declares `#[cfg(test)] pub mod tests;` and
`src/bobby/tests/mod.rs` declares exactly one module,
`sqlite::test_sqlite_affinity`. `Cargo.toml` has no `[[test]]` section, so
there is no integration-test tree the census could have missed. Upstream's
`src/main.rs:22` also carries `// mod tests;` commented out at the crate root —
no test content hides behind it.

Port, via `test-census.sh`: 18 examples, all in
`spec/bobby/sqlite/affinity_spec.rb`.

## Ledger — 1/1

| # | Upstream test | Property it pins | Port test | State |
|---|---|---|---|---|
| 1 | `test_sqlite_affinity_to_type_string` (`src/bobby/tests/sqlite/test_sqlite_affinity.rs:7-14`) | Every affinity variant reports its own SQLite type name — `NUMERIC`, `INTEGER`, `REAL`, `TEXT`, `BLOB`, `NULL` — because that name is what a cell's tooltip shows the user beside the value | `Bobby::Sqlite::Affinity #type_string "names every affinity"` (`spec/bobby/sqlite/affinity_spec.rb:11-25`) | **ported** |

All six of upstream's assertions survive: the port asserts the same six names
in one `eq(%w[NUMERIC INTEGER REAL TEXT BLOB NULL])`, variant for variant, and
constructs each through `described_class.new(type: …)` against the same six
constants. Not a partial port.

## Gap T1 — the suite has never been run

**There is no evidence any of the port's 18 examples passes.**

| | |
|---|---|
| Upstream harness | `.github/workflows/tests.yml` builds the Flatpak from `studio.planetpeanut.Bobby.devel.yml` with `run-tests: true`, on x86_64 and aarch64, on every push to `main`/`dev` and every PR |
| Port harness | `.rspec`, `spec/spec_helper.rb`, `Rakefile`, `.simplecov`, `.github/.codecov.yml`, `.gitlab-ci.yml` are all present. No GitHub Actions test workflow exists (`.github/` holds `aw/parity-scan.sh`, `dependabot.yml`, `FUNDING.yml`, `copilot_instructions.md`) |

What I observed:

```
$ bundle exec rspec
bundler: command not found: rspec
Install missing gem executables with `bundle install`

$ bundle install
Cannot write a changed lockfile while frozen.

$ ls Gemfile.lock
(absent)
```

The suite's own target cannot reach a runnable state in a fresh checkout, and
there is no committed lockfile and no CI job that would have caught it. The
skill's closing requirement is that "the port's suite passes under its own test
target (`rake test` / `make test`)" and that the result be reported as numbers
someone can re-run. The honest number here is **0 examples executed**.

This also leaves the single ported test unverified: `affinity_spec.rb` asserts
against `SQLite3::Blob` (`:65`, `:113`), so it needs the `sqlite3` gem, which
the gemspec does not declare (see `component-parity.md` G7). The spec may well
pass. Nobody has shown that it does.

**Behaviour still owed:** a person checking out this port and running its test
command sees the affinity test pass, and sees it again on every push.

**Fix:** declare the runtime gems in the gemspec, commit a `Gemfile.lock`, add
a CI job that runs the suite, and report the count.

## Extra — the port's own 17 examples

Not parity work. Parity is the floor; these are above it and they stay listed
separately so the 1/1 count above is never inflated by them. All in
`spec/bobby/sqlite/affinity_spec.rb`:

| Group | Examples | What they pin |
|---|---:|---|
| `.parse` | 6 | `BIGINT`→INTEGER, `VARCHAR(255)` truncated at the paren→TEXT, `CLOB`→TEXT, `DOUBLE`/`FLOATING POINT`→REAL, `""`→BLOB, `DECIMAL`→NUMERIC |
| `.from_value` | 3 | nil→NULL, integer value kept, blob length + `"DE AD BE EF"` hex preview |
| `#to_s` | 4 | em dash for NULL and for a value-less NUMERIC, `"12 BYTES"` for a blob, `"???"` for a variant that lost its value |
| `#dimmed?` | 1 | NULL, blob and value-less NUMERIC dim; a TEXT with a value does not |
| `#tooltip` | 3 | `"INTEGER 42"`, `"NULL"`, `"BLOB 01 02 …"` |

## Untested port code

Stated as fact, not as a parity row — upstream tests none of it either, so
none of it is owed under this ledger. It is worth knowing that 34 of the port's
35 `lib/` files have no spec:

`Sqlite::Database`, `Row` (including the rowid-vs-OFFSET query switch),
`Table`/`TableName` (including the validation that is the port's only defence
against identifier injection, since table names are interpolated into SQL),
`Column`, `Cache`, `ColumnSeparator`, `RowOrder`, `Cli`, `Log`, `App`,
`Settings`, `Util`, and every widget, dialog, action and the window.

`TableName.valid?` (`lib/bobby/sqlite/table.rb:22-28`) deserves a test most: it
is the single check standing between `Table.row_count`'s
`"SELECT COUNT(*) FROM #{table.name}"` (`:76`) and an arbitrary identifier.
