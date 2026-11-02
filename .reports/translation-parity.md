# Translation parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `9a3ce26f5edc81fdd0614ab6e3523ff09305463d` |
| Domain | **none** — neither tree has a gettext domain |
| Upstream messages (census) | **33** |
| Port messages (census) | **33** |
| Ported | **33** |
| Gaps in the census | **0** |
| Extra | **0** |
| `kind_mismatch` | **0** |
| Languages | upstream **4** (`de`, `es`, `fr`, `pt`, as `xml:lang` attributes), port **4** |
| `unresolved` markers | **0** |
| Catalogue parity | **true** |
| Source-literal text axis | **1 gap** — see below |

## Step 1 — census both trees

```
$ msgid-census.sh <upstream> → 33 rows
$ msgid-census.sh <port>     → 33 rows

$ diff <(cut -f1,2 up.msg | sort -u) <(cut -f1,2 port.msg | sort -u)
(no output)

$ diff <(cut -f1,2,3 up.msg | sort -u) <(cut -f1,2,3 port.msg | sort -u)
(no output)
```

**The key sets are identical, byte for byte, and so are the `kind` columns.**
Both censuses draw from the same two files and in the same proportion:

| Source | Upstream rows | Port rows |
|---|---:|---:|
| `data/studio.planetpeanut.Bobby.desktop` | 1 | 1 |
| `data/studio.planetpeanut.Bobby.metainfo.xml` | 32 | 32 |

Those two files are byte-identical between the trees apart from one appended
`<release version="0.1.0">` in the port's metainfo, whose `<li>` is a release
note and so is excluded by xgettext's ITS rules — which is why the count did
not move. Verified:

```
$ diff <upstream>/data/studio.planetpeanut.Bobby.desktop  data/…desktop        → identical
$ diff <upstream>/data/studio.planetpeanut.Bobby.gschema.xml data/…gschema.xml → identical
$ diff <upstream>/data/studio.planetpeanut.Bobby.metainfo.xml data/…metainfo.xml
74a75,81   >  <release version="0.1.0" date="2026-11-02"> … </release>
```

## There is no catalogue to inherit, and that is the whole story

| | |
|---|---|
| `po/` directory | **neither tree has one** |
| `LINGUAS`, `POTFILES.in`, `*.pot`, `*.po`, `*.mo` | none in either tree |
| gettext calls (`_`, `N_`, `C_`, `ngettext`, `n_`, `p_`, `s_`, `dgettext`, …) | **zero** in `src/**/*.rs` and zero in `lib/**/*.rb` |
| `i18n.gettext` / `gettext` in the build files | absent from `meson.build`, `meson.options`, `Cargo.toml` |
| gettext domain | none — so `domain_matches` is vacuously satisfied and there is no `.mo` filename to get wrong |

Upstream's user-visible strings are English literals compiled into the binary.
The port's are English literals in Ruby. **The port cannot have destroyed
donated translation work, because there is none to destroy** — this is the rare
case where the inherited asset is four `xml:lang` attributes rather than
fourteen thousand translated strings, and both apps carry the same four.

The 33 messages are therefore not a UI catalogue at all. They are the metadata
strings the three non-code sources contribute, which the skill names as the
ones nobody remembers:

- the desktop entry's `Comment` (`Browse SQLite files`);
- the metainfo's `<name>`, `<summary>` (and its four localised variants), `<p>`, `<li>` (3 feature lines), `<caption>` (3) and `<keyword>` (10 source + 11 localised).

The GSettings schema contributes nothing, because
`data/studio.planetpeanut.Bobby.gschema.xml` carries no `<summary>` or
`<description>` on any of its four keys — in either tree. That is a defect
upstream, today: the four preference keys have no translatable descriptions,
which is what `gsettings describe` and the GNOME settings tooling read. The
port inherits the defect byte-for-byte, which is correct for parity and worth
reporting upstream.

### The localised strings, both trees

| Language | `<summary>` | `<keyword>` |
|---|---|---|
| `de` | `SQLite-Datenbanken anzeigen` | `Datenbank`, `Tabelle` |
| `es` | `Ver bases de datos SQLite` | `base de datos`, `tabla` |
| `fr` | `Afficher les bases de données SQLite` | `base de données`, `table` |
| `pt` | `Visualizar bancos de dados SQLite` | `banco de dados`, `tabela` |

All eleven localised keyword entries and all four localised summaries are
present in the port with identical bytes, including the accented characters.
Nothing was retyped.

### Cross-check against a real catalogue

Not possible, and that is a statement of fact rather than a reason to stop: the skill's `.po` cross-check
needs a `po/` directory, a committed `.pot`, or both, and there is neither on
either side. The substitute performed instead was the direct file diff above —
which is stronger here, because the two trees' message sources are the *same
files*, so the comparison is byte-level rather than key-level.

### Unresolved markers

Zero on both sides. There is no marker whose argument is an expression,
because there are no markers.

## Step 2 — the metrics

| # | Metric | Upstream | Port |
|---|---|---:|---:|
| 1 | messages (distinct `(ctxt, id)` keys) | 33 | 33 |
| 2 | occurrences (call sites) | 33 | 33 |
| — | reused | 0 | 0 |
| — | plural | 0 | 0 |
| — | with context | 0 | 0 |
| 3 | languages | 4 | 4 |
| 4 | translated strings | 15 | 15 |
| 5 | uses per message | 1, uniformly | 1, uniformly |

`comm -23 up.keys port.keys` → 0 gaps.
`comm -13 up.keys port.keys` → 0 extra.
`comm -12 up.keys port.keys` → 33 ported.

No message is reached from more than one site in either tree, so there is no
`Uses` column to read and no load-bearing string to lose a call site of. The
`uses_mismatch` and `extra` counts are both zero, and neither would have
blocked parity in any case.

## The source-literal text axis — one gap

The census above covers the data files, and the data files are where every
*extractable* message lives. But `component-parity`'s text axis asks a
different question of the source: does each component say what its original
said? Since neither app marks its UI strings, that comparison was done by
extracting every string literal from upstream's 34 `.rs` files (235 distinct)
and testing each against the port's `lib/` and `exe/`:

```
$ grep -rhoE '"[^"]{3,}"' <upstream>/src --include='*.rs' | sort -u | wc -l
235
$ while read s; do grep -qF -- "$s" <port literals> || echo "MISSING: $s"; done
```

73 reported missing. 72 of them are correspondences, each located:

- **Rust format templates** — `"{} {}"`, `"| {} |"`, `"{:02X}"`, `"Row {} copied to clipboard"`, `"{row_number} / {row_count}"`, `"Views – {view_count}"`, `"{SYMBOL_KEY} PRIMARY_KEY  {s}"`, `"<span font_features='tnum=1'>‘{selection}’  copied to clipboard</span>"`, `"{timestamp} | {message}"`, `"\x1b[31m{app} error:\x1b[0m {message}"`, `"share/applications/{command_name}.desktop"`, `"win.copy-val::{}:{}"`, `"win.table::{}"`, `"SELECT COUNT(*) FROM {}"`, `"PRAGMA table_info({});"` and the rest. The port writes the same strings with Ruby interpolation, so the bytes around the placeholder match and the placeholder itself does not. Each one was read and confirmed equal in value.
- **`Err` strings from the two tree walks** — `"Missing widget named 'switcher'"`, `"Expected MenuButton, but got {}"`, `"Could not cast to ApplicationWindow"`, `"Database not found on window"` and eleven more. `widget_by_name` and `find_column_view` have no counterpart in the port — the correspondence is located at `lib/bobby/util.rb:11-18` and in the memoized accessors it names, so neither do their failure messages. Never shown to a user in either app.
- **`Err` strings from constructors that return nil in Ruby** — `"Invalid column separator"`, `"Empty string"`, `"Table name contains invalid characters"`, `"Table name is empty or starts with sqlite_"`. Upstream's callers all `unwrap_or_default()` these, so they are never read; the port returns nil at the same points.
- **Commented-out upstream** — `"Copy Rows"`, `"win.copy-rows::{}"`, `"win.open-table-menu"`. Absent from both running apps.
- **`eprintln!` diagnostics** — `"Failed to bind index list item: {e}"` and four siblings, against the port's `Log.error('Missing column')` and equivalents.
- **Debug leftovers** — `"item({index})"`, `"n_items()"`, `"Caching {CACHE_PAGE_SIZE} rows around {index}"`, all commented out upstream.
- **Build-time constants** — `CARGO_PKG_HOMEPAGE` and friends, which are `App::HOMEPAGE` and `Rb::VERSION` in the port.

The seventy-third is a real gap, and it is recorded in **both** ledgers as the
skill requires — here against the message, and in `.reports/component-parity.md`
against the `win.copy-val` action:

| msgid | Upstream | Port | State |
|---|---|---|---|
| `Copied to clipboard` | `src/gtk/actions/win_copy_val.rs:52` — built as the toast title for a value at or past the 96-byte cutoff | nothing: `grep -rn 'Copied to clipboard' lib/ exe/ test/` is empty | **gap** |

`text_owed`: `Copied to clipboard`

Upstream never displays it — the `add_toast` call sits behind the same `< 96`
test that chooses the other title — so the string is dead on upstream's side
too. It is still one user-visible literal upstream has and the port does not,
and if upstream ever fixes the dead branch the port will show nothing where
upstream shows a confirmation. That makes it the port's debt, not upstream's
licence.

Two more rows on this axis belong to the component ledger rather than to the
message set, because the bytes match and the *rendering* does not:

- Every integral or very large REAL value: `1.0` in the port against `1` upstream, and `1.0e+300` against 301 digits. Gap **C-17**. Not a msgid — `Affinity`'s Display is not a string literal — but it is user-visible text that differs.
- The 96-unit toast cutoff is characters in the port and bytes upstream. Gap **C-18**.

## Step 3 — the ledger, and what it degenerates to

Per the skill's "when upstream has no catalogue" shape, there is no table of 33
rows to write: every row is `ported`, every key is byte-identical, and the
grouping by source file is the two-row table in Step 1.

**Neither app is internationalised.** Upstream ships no `po/`, no gettext, no
`.mo` and no translator-facing extraction path at all; every one of the ~60
user-visible UI strings in `src/` is an unmarked English literal, and the only
localisation either project has is the four `xml:lang` summaries and eleven
localised keywords in the AppStream metadata. The port reproduces that state
exactly, which is what parity means here and is not a state anyone should be
pleased with: **a GNOME app whose entire UI is untranslatable is an upstream
defect the port has faithfully inherited**, and the port has no standing to fix
it unilaterally, because inventing msgids the upstream catalogue does not have
would hand translators keys that match nothing. Report it upstream.

## Rules check

- Key sets equal: 33 = 33, `diff` empty ✓
- Every key byte-identical, quotes normalised on both sides ✓
- `kind` identical on every shared key ✓
- Languages carried: 4 of 4, all eleven localised keywords and four localised summaries intact ✓
- Domain matches: vacuous — there is no domain on either side ✓
- Unresolved markers: 0 ✓
- No msgid was reworded to match the port ✓
- Source-literal text axis: **1 gap** (`Copied to clipboard`), recorded in both ledgers ✓

**Verdict: catalogue parity is 33/33 with 0 gaps and `parity: true`. The
source-literal text axis has one gap, `Copied to clipboard`, which is also open
as C-19 in the component ledger. Both apps are otherwise untranslatable, which
is upstream's defect and the port's inheritance.**
