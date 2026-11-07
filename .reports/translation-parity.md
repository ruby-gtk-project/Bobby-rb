# Translation parity — Bobby

**Reconfirmed again this round against `HEAD` (`d8799c0`).** The one commit
since the prior reconfirmation (`ada9290`) touches only `PORTING.md`, which
carries no translatable string, so the 33/33 census below is unchanged.
Re-derived live this round, not assumed: `.claude/skills/translation-parity/scripts/catalogue.rb`
was run against a worktree of `origin/main` and against this checkout, and
the two catalogues (189 lines each) are identical except for the header's
role/path/ref/sha fields — every one of the 33 msgids, every `kind`, and all
four languages' localised keywords and summaries match byte for byte.

**Reconfirmed this round against `HEAD` (`ada9290`).** The one commit since
the last reconfirmation (`314c519` → `ada9290`, "Port Flatpak packaging")
touches `.github/workflows/flatpak.yml`, `Gemfile.flatpak`, `PORTING.md`,
`build-aux/dist-vendor.sh` and the two `studio.planetpeanut.Bobby*.yml`
manifests — none of them `metainfo.xml`, `.desktop`, `Bobby.doap` or any
`lib/`/`exe/` file carrying a user-visible string, so the 33/33 census below
is unchanged. The data files were re-diffed against `origin/main` again this
round with the same result as before: identical apart from the three
screenshot-URL swaps and the appended `<release>` block. No `po/`, `.ui`,
`.blp` or translatable-string-bearing file changed between the previously
audited commit and now — the commits since (`e11c5bc`, `9a4be48`, et al.) touched
`sqlite/affinity.rb`, `sqlite/cache.rb`, `sqlite/row.rb`,
`actions/win_copy_val.rb`'s byte-counting logic, and GPLv3 headers, none of
which add, remove or reword a user-visible string. `win_copy_val.rb`'s two
toast strings (`LONG_TITLE = 'Copied to clipboard'` and the tabular-figures
markup template) are unchanged text, only the condition that gates them
changed (byte vs character count), so the census below still holds. The data
files (`metainfo.xml`, `.desktop`, `Bobby.doap`) were re-diffed against
`origin/main` this round: identical apart from the expected repository-URL
swap in three screenshot `<image>` elements and one appended
`<release version="0.1.0">` block, neither of which is a translatable string.
PORTING.md's own "34/34" (message parity, including the one dead non-msgid
literal that also matches byte-for-byte) and "33/33" (msgid count only) are
not a contradiction — they are two different counts of the same census,
both consistent with the 33/33 below.

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `9a3ce26f5edc81fdd0614ab6e3523ff09305463d` (re-verified unchanged through `314c519`) |
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

**Corrected this round — the line above in this same document was wrong.**
The seventy-third row was reported as a gap in an earlier pass of this
document and the sentence at the top of this file even names the commit that
closed it (`e11c5bc`, "the byte-counted copy cutoff") without the rest of the
document being reconciled against it. Checked live, now:

```
$ grep -rn 'Copied to clipboard' lib/ exe/ test/
lib/bobby/actions/win_copy_val.rb:42:      LONG_TITLE = 'Copied to clipboard'
test/drive_bobby.rb:1380:        Bobby::Actions::WinCopyVal::LONG_TITLE == "Copied to clipboard"
```

| msgid | Upstream | Port | State |
|---|---|---|---|
| `Copied to clipboard` | `src/gtk/actions/win_copy_val.rs:52` — built as the toast title for a value at or past the 96-byte cutoff | `lib/bobby/actions/win_copy_val.rb:42`, asserted at `test/drive_bobby.rb:1380` | **ported** |

Upstream never displays it — the `add_toast` call sits behind the same `< 96`
test that chooses the other title — so the string is dead on upstream's side
too, and it was dead in the port as well until `e11c5bc` added the constant.
It now exists on both sides and the drive asserts its value, so this closes
as **C-19**, matching `.reports/component-parity.md`'s reconciled header. The
defect this round adds to the record is not in the port — it is that this
document asserted "grep is empty" after a commit had made that false, and
nothing caught it until this pass. That is the exact failure pattern
`accountability-ensurance.md` exists to name, and it is cross-filed there as
part of gap-tracking hygiene, since the accountability pass that produced the
current `.reports/accountability-ensurance.md` did not itself catch it.

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
- Source-literal text axis: **0 open gaps** — `Copied to clipboard` (formerly
  C-19) is ported and asserted; reconciled this round after this document
  itself carried the stale claim past the commit that closed it ✓

**Verdict: catalogue parity is 33/33 with 0 gaps and `parity: true`. The
source-literal text axis, which previously carried one gap (`Copied to
clipboard` / C-19), is now also clean — the string was added in `e11c5bc` and
this document's own claim that it was missing had gone stale. Both apps are
otherwise untranslatable, which is upstream's defect and the port's
inheritance. Two rendering-only divergences remain tracked in the component
ledger, not here: C-17 (REAL formatting) and C-18 (byte vs character cutoff).**
