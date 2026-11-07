# Porting status

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on
`ruby` and is written from scratch against upstream as the spec — never check
out or merge the upstream ref.

| | |
|---|---|
| Upstream ref | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port branch | `ruby` |
| Last parity audit | `.reports/` @ port `9a3ce26`, audited through C-23 |
| Open gaps now | **4** — C-12, C-13, C-14, C-23. C-07 was closed in `9a4be48`, after the last parity audit, so `.reports/component-parity.md` still lists it as open; this file is the current source of truth for gap status. |

## Upstream

Bobby is a read-only SQLite database browser: you open a `.db` file by
argument, file dialog or drag-and-drop, pick a table or view from a header-bar
menu button, and read its rows in a `Gtk.ColumnView` with per-cell and per-row
clipboard copy.

It is implemented in Rust (gtk-rs `gtk4` + `libadwaita`, `rusqlite`) and built
with meson driving cargo. There are no `.ui` files, no blueprint, no
GResource and no stylesheet — every widget is constructed in code, and every
CSS class used is a GTK or libadwaita platform class. There is no `po/`
directory and no gettext: UI strings are English literals in the source.

## Done

Every upstream `src/**/*.rs` file has a Ruby counterpart. "Done" here means a
counterpart exists and was checked against upstream; the gap ids in the last
column are defects found in it by the audit.

| Port | Upstream | Gaps |
|---|---|---|
| `lib/bobby/application.rb`, `lib/bobby/app.rb`, `lib/bobby/cli.rb`, `lib/bobby/log.rb` | `src/gtk/lib.rs`, `src/main.rs`, `src/app.rs`, `src/cli.rs`, `src/log.rs`, `src/gui.rs` | — |
| `lib/bobby/window.rb` | `src/gtk/windows/window.rs` | C-03, C-22 (both deliberate; see FINDINGS.md) |
| `lib/bobby/widgets/content.rb` | `src/gtk/widgets/content.rs` | — |
| `lib/bobby/widgets/item.rb` | `src/gtk/widgets/item.rs` | — |
| `lib/bobby/widgets/switcher.rb` | `src/gtk/widgets/switcher.rs` | — |
| `lib/bobby/widgets/menu.rb` | `src/gtk/widgets/menu.rs` | — |
| `lib/bobby/widgets/button.rb` | `src/gtk/widgets/button.rs` | — |
| `lib/bobby/widgets/drop_target.rb` | `src/gtk/widgets/drop_target.rs` | — |
| `lib/bobby/dialogs/about.rb` | `src/gtk/dialogs/about.rs` | — |
| `lib/bobby/dialogs/file.rb` | `src/gtk/dialogs/file.rs` | — |
| `lib/bobby/dialogs/preferences.rb` | `src/gtk/dialogs/preferences.rs` | — |
| `lib/bobby/dialogs/shortcuts.rb` | `src/gtk/dialogs/shortcuts.rs` | — |
| `lib/bobby/actions/app_about.rb`, `app_open.rb`, `app_preferences.rb`, `app_quit.rb`, `app_shortcuts.rb` | `src/gtk/actions/app_*.rs` | — |
| `lib/bobby/actions/win_close.rb`, `win_reload.rb`, `win_switch_table.rb` | `src/gtk/actions/win_close.rs`, `win_reload.rs`, `win_switch_table.rs` | — |
| `lib/bobby/actions/win_copy_row.rb`, `win_copy_val.rb` | `src/gtk/actions/win_copy_row.rs`, `win_copy_val.rs` | — |
| `lib/bobby/sqlite/affinity.rb` | `src/bobby/sqlite/affinity.rs` | — |
| `lib/bobby/sqlite/cache.rb` | `src/bobby/sqlite/cache.rs` | — |
| `lib/bobby/sqlite/column.rb` | `src/bobby/sqlite/column.rs` | — |
| `lib/bobby/sqlite/database.rb` | `src/bobby/sqlite/database.rs` | — |
| `lib/bobby/sqlite/row.rb` | `src/bobby/sqlite/row.rs` | — |
| `lib/bobby/sqlite/table.rb` | `src/bobby/sqlite/table.rs` | — |
| `lib/bobby/util.rb` | `src/gtk/util.rs` | — |
| `rakelib/data_install.rake` | `data/meson.build`, `data/icons/meson.build` | — |
| `info/release-steps.md`, `.github/CONTRIBUTING.md` | the same paths upstream | — |
| `lib/bobby/settings.rb` | no single upstream file — the GSettings access spread through `src/app.rs` and `src/gtk/dialogs/preferences.rs` | — |
| `spec/bobby/sqlite/affinity_spec.rb` | `src/bobby/tests/sqlite/test_sqlite_affinity.rs` | — |
| `data/studio.planetpeanut.Bobby.desktop`, `.gschema.xml`, `.metainfo.xml`, `gschemas.compiled`, `data/icons/**`, `data/screenshots/**` | the same paths upstream | — |

Upstream's `src/bobby/mod.rs`, `src/bobby/prelude.rs`, `src/gtk/mod.rs`,
`src/gtk/actions/prelude.rs`, `src/gtk/windows/prelude.rs` and
`src/bobby/tests/mod.rs` are Rust module plumbing with nothing to port.

Parity audit verdict per unit: `content`, `switcher`, `main menu`,
`open button`, `drop target`, the four dialogs and the window's state machine
reached parity under a driven run (`nix develop`, GTK 4.22.4, xvfb). The drive
is now **474 of 474 checks passed, 16 screenshots** in `tmp/shots/`, run with
`nix develop --command xvfb-run -a ruby test/drive_bobby.rb` → `DRIVE OK`
(reconfirmed this round). Message parity is 34/34 byte-identical, the extra
one being `Copied to clipboard` (C-19). Upstream's one test is ported 1 → 1,
but the bijection does not hold over the full suite: `spec/bobby/sqlite/row_spec.rb`
adds six examples for `Row.page`, a method upstream does not have, so 6 of the
36 examples map to no upstream test (gap **T-01**, see
`.reports/test-parity.md`). The suite runs from the command the dev shell
prints: 36 examples, 0 failures (reconfirmed this round).

## Not started

No upstream source component is unstarted. What is still absent is upstream
packaging, and only the Flatpak half of it:

- `studio.planetpeanut.Bobby.yml`, `studio.planetpeanut.Bobby.devel.yml`
  (Flatpak manifests), `.github/workflows/flatpak.yml`,
  `build-aux/dist-vendor.sh`

What used to be in this list and is now here:

- `LICENSE.txt` and the five-line GPLv3 header — the licence landed in
  `ca5cafa`, the header is on all 39 files in `lib/` and `exe/`
- `meson.build`, `meson.options`, `data/meson.build`, `data/icons/meson.build`
  — the port has no meson, and what the two `data/` ones are *for* is
  `rakelib/data_install.rake`: `rake data:install` puts the desktop entry, the
  metainfo, the schema and the two icons under `PREFIX`
- `data/screenshots/*.png` — three of the port's own, from the drive, with the
  metainfo repointed at this repository
- `.github/CONTRIBUTING.md`, `info/release-steps.md`

## Open gaps

Four C-series gaps, and the figures above are this round's. Everything else
the audits raised through C-23 is in *Closed* below, with the commit that
closed it. There is also one reporting gap, **T-01**: `spec/bobby/sqlite/row_spec.rb`'s
six examples test `Row.page`, which upstream has no test for, so the port's
36-example suite is not a 1 → 1 bijection with upstream's single test even
though that one test is ported correctly. Nothing to port closes this — it is
a record-keeping gap (the prior parity round kept asserting "bijection holds"
after this file landed), tracked in `.reports/test-parity.md`.

- **C-12 — no Flatpak manifest**, so `App.flatpak?`, `PREFIX = '/app'`, the
  `' (Flatpak)'` suffix, the XDG overrides and the non-checkout branch of
  `Settings.install_schema_dir` have never run. Upstream:
  `studio.planetpeanut.Bobby.yml`, `.devel.yml`.
- **C-13 — no Flatpak CI job.** Upstream: `.github/workflows/flatpak.yml`.
- **C-14 — no vendoring script.** Upstream's `build-aux/dist-vendor.sh` feeds
  `cargo --offline` inside the Flatpak build; the Bundler equivalent is
  `bundle package`, and nothing in the port runs it.
- **C-23 — two of the three ways to open a file have never been driven end to
  end.** `Gdk::FileList.new([...])` raises `NotImplementedError: TODO: in Ruby
  -> GIArgument(array/C)[interface(interface)](GFile)`, so the drop target's
  accepting branch is reachable only from a real pointer drag; and
  `Gtk::FileDialog`'s chooser is asynchronous and raises on cancel. Recorded
  in `.reports/drive-bobby.md:56-70`. What would close it: capturing the
  `Gdk::FileList` GTK hands the `drop` handler during a synthesised drag, and
  driving `open_multiple_finish` against a crafted result.

## Closed

| Gap | What it was | Closed in |
|---|---|---|
| C-01 | `bobby --version` exited 1 on a headless box | `ca5cafa` |
| C-02 | the empty state rendered a missing-image placeholder | `ca5cafa` |
| C-03 | the reload banner fires `win.reload` where upstream sets the inert `app.reload` | recorded as a deliberate divergence in FINDINGS.md, this round |
| C-04 | `top_bar_style` was reset to `:flat` on leaving the content state | `ca5cafa` |
| C-05 | blob cells were misclassified and could crash the bind handler | `ca5cafa` |
| C-06 | both copy actions raised, so Copy copied nothing | `ca5cafa` |
| C-08 | the metainfo pointed at pictures of upstream's app | this round |
| C-09 | no `LICENSE.txt` | `ca5cafa` |
| C-10 | no GPLv3 header on any source file | this round |
| C-11 | nothing installed the desktop entry, the schema or the icons | this round, `rakelib/data_install.rake` |
| C-15 | `.github/CONTRIBUTING.md` and `info/release-steps.md` absent | this round |
| C-16 | the port could not start in its own devShell | `ca5cafa` |
| C-17 | REAL cells rendered with Ruby's `Float#to_s` rather than Rust's Display | this round |
| C-18 | the 96-unit copy cutoff counted characters, not bytes | this round |
| C-19 | upstream's `Copied to clipboard` had no counterpart | this round |
| C-20 | not one check asserted a toast | this round, a toast section in the drive |
| C-21 | no declared test command ran | this round, `spec/spec_helper.rb` |
| C-22 | the port shows an error page where upstream shows nothing | recorded as a deliberate divergence in FINDINGS.md, this round |
| C-07 | `Sqlite::Cache` read every row of a table eagerly into a `Gio::ListStore`, against upstream's windowed `DatabaseCacheModel` | `9a4be48` — `Cache` is now itself a `Gio::ListModel`, paging 256 rows at a time and evicting beyond ±256 |

C-21 is closed in the half that was a defect: the dev shell's own command runs
the suite, with `.rspec` and `spec_helper.rb` in force. The root bundle still
does not resolve on Ruby 3.4 and there is still no `Gemfile.lock`; FINDINGS.md,
*About the bindings*, has the measured reason and `.gitignore:4`.

## Blockers

Things that cannot be ported as upstream writes them, and why.

- **`DatabaseCacheModel` (`src/bobby/sqlite/cache.rs`) is no longer a
  blocker.** It subclasses GObject and implements the `Gio.ListModel`
  interface vfuncs `item`/`n_items`/`item_type`. Earlier rounds assumed a Ruby
  class could not implement a GInterface's vfuncs; `9a4be48` tested that
  assumption and it was false. `Sqlite::Cache` (`lib/bobby/sqlite/cache.rb`)
  is itself a `type_register`ed `GLib::Object` that `include`s
  `Gio::ListModel` and defines `virtual_do_get_item`,
  `virtual_do_get_n_items` and `virtual_do_get_item_type`, with the same
  256-row paging and ±256 eviction as upstream. The one ordering rule that
  makes this work: `include Gio::ListModel` must come *after*
  `type_register`, or the GType is registered without the interface and the
  model silently answers 0 items.
- **`glib::BoxedAnyObject` ↔ `Sqlite::RowObject`.** The mechanism has no Ruby
  equivalent: upstream boxes a plain Rust `Row` into a GObject to put it in a
  list model, and ruby-gnome exposes no `BoxedAnyObject`. The behaviour is
  built — `Sqlite::RowObject` (`lib/bobby/sqlite/cache.rb:17-31`) is a
  `type_register`ed `GLib::Object` carrying the `Row`, and the content
  widget's bind handler reads `#row` off it. What the substitution costs is
  the weak Ruby/GObject association: a `RowObject` referred to only by the
  store loses its Ruby half, which is why `Sqlite::Cache` holds them too.
- **SQLite immutable URI open flags.** Upstream opens via a file URI with
  `immutable=1` and `OpenFlags::SQLITE_OPEN_URI`. The `sqlite3` gem opens by
  path with a `readonly:` option and does not expose URI open flags, so the
  `immutable` optimisation has no direct translation. `PRAGMA
  query_only`/`foreign_keys`/`busy_timeout` are reachable through plain
  `execute` and the audit drove them as parity.
- **`window.set_data("db", ...)` and the `widget_by_name` /
  `find_column_view` tree walks (`src/gtk/util.rs`) do not port.** They exist
  only because upstream has no widget subclasses; unsafe GObject user data is
  not portable. Everything upstream derives from `widget_name` became explicit
  Ruby attributes and memoized accessors (`lib/bobby/window.rb:186-258`,
  `lib/bobby/widgets/content.rb:99-139`). The audit accepted this as
  correspondence, not a gap.
- **GSettings schema compilation.** The app will not start unless the schema
  is compiled and on `GSETTINGS_SCHEMA_DIR`. The port works around this with a
  committed `data/gschemas.compiled` and `Settings::SCHEMA_DIR`. Upstream has
  the same unresolved TODO in `src/app.rs`. Flatpak manifests, meson/cargo and
  icon installation are packaging, not components.
- **No translation work to port.** No `po/`, no gettext calls, no GResource —
  UI strings are English literals in Rust, and only four `xml:lang` summaries
  in the metainfo are translated. The port keeps literals rather than inventing
  a catalogue. Parity is 33/33 msgids, byte-identical.
- **`Adw.Banner` in the content state is dead code upstream** — built but
  never revealed, because no file monitor was ever written
  (`// .revealed(true) // TODO`). The port builds the widget for parity and
  does not invent the file-watching behaviour.
- **Preferences `ComboRow`s are not `settings.bind`ed upstream.** Upstream
  reads the enum choices out of the GSettings schema itself via
  `SettingsSchemaSource` → `schema.key(key).range()` and maps index to value by
  position. The Ruby bindings expose schema ranges awkwardly, so the port
  hard-codes the choice lists and keeps the index ↔ value mapping by hand.

Two blockers named by the earlier survey have since been resolved and are no
longer blockers:

- `Adwaita::ShortcutsDialog`/`ShortcutsSection`/`ShortcutsItem` (libadwaita
  1.9+) **are** exposed by the installed Ruby bindings;
  `lib/bobby/dialogs/shortcuts.rb` uses them and the audit screenshotted the
  result at parity. No `Gtk::ShortcutsWindow` fallback was needed.
- `Adwaita::Application`/`Adwaita::ApplicationWindow` remain broken in the
  bindings, and the port no longer uses them: `lib/bobby/application.rb` is a
  `Gtk::Application` with `Adwaita.init`, and `lib/bobby/window.rb:187` builds
  a `Gtk::ApplicationWindow` with a hidden titlebar.
