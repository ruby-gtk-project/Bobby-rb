# Porting status

Resume point for the next run. Upstream is the `origin/main` ref in this same
repository; read it with `git show origin/main:<path>`. The port lives on
`ruby` and is written from scratch against upstream as the spec — never check
out or merge the upstream ref.

| | |
|---|---|
| Upstream ref | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port branch | `ruby` |
| Last parity audit | `.reports/` @ port `28bb3a5`, **16 open gaps**, clean = false |

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
| `lib/bobby/application.rb`, `lib/bobby/app.rb`, `lib/bobby/cli.rb`, `lib/bobby/log.rb` | `src/gtk/lib.rs`, `src/main.rs`, `src/app.rs`, `src/cli.rs`, `src/log.rs`, `src/gui.rs` | C-01 |
| `lib/bobby/window.rb` | `src/gtk/windows/window.rs` | C-02, C-03, C-04 |
| `lib/bobby/widgets/content.rb` | `src/gtk/widgets/content.rs` | — |
| `lib/bobby/widgets/item.rb` | `src/gtk/widgets/item.rs` | C-05 |
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
| `lib/bobby/actions/win_copy_row.rb`, `win_copy_val.rb` | `src/gtk/actions/win_copy_row.rs`, `win_copy_val.rs` | C-06 |
| `lib/bobby/sqlite/affinity.rb` | `src/bobby/sqlite/affinity.rs` | C-05 |
| `lib/bobby/sqlite/cache.rb` | `src/bobby/sqlite/cache.rs` | C-07 |
| `lib/bobby/sqlite/column.rb` | `src/bobby/sqlite/column.rs` | — |
| `lib/bobby/sqlite/database.rb` | `src/bobby/sqlite/database.rs` | — |
| `lib/bobby/sqlite/row.rb` | `src/bobby/sqlite/row.rs` | — |
| `lib/bobby/sqlite/table.rb` | `src/bobby/sqlite/table.rs` | — |
| `lib/bobby/util.rb` | `src/gtk/util.rs` | C-06 |
| `lib/bobby/settings.rb` | no single upstream file — the GSettings access spread through `src/app.rs` and `src/gtk/dialogs/preferences.rs` | — |
| `spec/bobby/sqlite/affinity_spec.rb` | `src/bobby/tests/sqlite/test_sqlite_affinity.rs` | test target does not run (see Open gaps) |
| `data/studio.planetpeanut.Bobby.desktop`, `.gschema.xml`, `.metainfo.xml`, `gschemas.compiled`, `data/icons/**` | the same paths upstream | C-02, C-08 |

Upstream's `src/bobby/mod.rs`, `src/bobby/prelude.rs`, `src/gtk/mod.rs`,
`src/gtk/actions/prelude.rs`, `src/gtk/windows/prelude.rs` and
`src/bobby/tests/mod.rs` are Rust module plumbing with nothing to port.

Parity audit verdict per unit: `content`, `switcher`, `main menu`,
`open button`, `drop target`, the four dialogs and the window's state machine
reached parity under a driven run (`nix develop`, GTK 4.22.4,
`gtk4-broadwayd`, 86 checks over 22 steps, 4 screenshots in `.reports/shots/`).
Message parity is 33/33 byte-identical. Test parity is a 1 → 1 bijection.

## Not started

No upstream source component is unstarted. What is absent is upstream
packaging and project files, none of which has a Ruby counterpart:

- `LICENSE.txt` (GPLv3) and the five-line GPLv3 header upstream carries on all
  34 `.rs` files — absent from every `lib/**/*.rb`
- `meson.build`, `meson.options`, `data/meson.build`, `data/icons/meson.build`
  — nothing in the port installs the icons or the schema
- `studio.planetpeanut.Bobby.yml`, `studio.planetpeanut.Bobby.devel.yml`
  (Flatpak manifests), `build-aux/dist-vendor.sh`,
  `.github/workflows/flatpak.yml`
- `data/screenshots/*.png` (4) — the committed metainfo still points at
  upstream's
- `.github/CONTRIBUTING.md`, `info/release-steps.md`

## Open gaps

The last audit (`.reports/component-parity.md`) reports **16** open gaps,
C-01 through C-16, and clean = false. The orchestrating script passed in a
figure of 12; the reports in the tree say 16, and 16 is what is recorded here.
`.reports/test-parity.md` reports 0 gaps in the test bijection but a failed
proof condition; `.reports/translation-parity.md` reports 0 gaps;
`.reports/accountability-ensurance.md` reports 5 gaps with no record anywhere
in the repository and 2 false statements in `FINDINGS.md`.

The two that break shipped behaviour:

- **C-05 — blob cells are misclassified and can crash the bind handler.**
  `Affinity.from_value` (`lib/bobby/sqlite/affinity.rb:56-63`) matches
  `SQLite3::Blob`, but the `sqlite3` gem returns blob columns as plain
  `ASCII-8BIT` `String`; that arm is unreachable from any read path. Cells
  render raw bytes instead of `2 BYTES`, are not dimmed, and get a `TEXT`
  tooltip. With bytes that are not valid UTF-8, `Gtk::Label#text=` raises
  `Encoding::UndefinedConversionError` inside `Item.write_text`
  (`lib/bobby/widgets/item.rb:34`) and the table does not render at all.
  `spec/bobby/sqlite/affinity_spec.rb:72,120` pass only because they
  hand-construct `SQLite3::Blob.new`.
- **C-06 — both copy actions raise, so Copy copies nothing.**
  `Bobby::Util.copy_to_clipboard` (`lib/bobby/util.rb:27`) calls
  `Gdk::Clipboard#set_text`, which does not exist in ruby-gnome; the method is
  `#set`. Everything downstream (row formatting, separator preference, toast,
  cell targeting, the 96-character cutoff) was verified correct with the call
  stubbed.

The rest:

- **C-01** — `bobby --version`/`--help`/`--deps`/`--env` exit 1 with a
  `Gtk::InitError` on a headless box, because the `gtk4` gem runs `gtk_init` at
  require time and `exe/bobby` requires `bobby` before parsing argv. Upstream
  parses args before `gtk_init`.
- **C-02** — the empty state renders a missing-image placeholder: the icon
  SVGs are committed but nothing installs them into an icon theme.
- **C-03** — the reload banner points at `win.reload`, which works; upstream
  points at a nonexistent `app.reload`, so upstream's button is inert. A
  divergence from the spec, recorded only in a class comment.
- **C-04** — the port resets `top_bar_style` to `:flat` in
  `show_empty_state`/`show_error_state`; upstream never sets it back, so
  upstream keeps the raised border after content → error.
- **C-07** — no lazy paging: `lib/bobby/sqlite/cache.rb:56` fills a
  `Gio::ListStore` with every row before the window appears, against
  upstream's 256-row paged model. See Blockers.
- **C-08** — no screenshots; the metainfo references upstream's.
- **C-09 / C-10** — no `LICENSE.txt`, no GPLv3 source headers, while the
  gemspec declares `GPL-3.0-or-later` and the about dialog shows
  `License::GPL_3_0`.
- **C-11 … C-15** — the missing packaging and project files listed under *Not
  started*.
- **C-16** — the port cannot start in its own documented environment.
  `nix/Gemfile` lists only `adwaita` and `gtk4`, omitting `sqlite3`, which
  `lib/bobby.rb:3` requires; `nix develop --command ruby -Ilib -e 'require
  "bobby"'` fails with `cannot load such file -- sqlite3`, and
  `packages.default` builds from the same derivation. Also `flake.nix:146`
  compiles schemas from `data/schemas/*.gschema.xml`, a directory that does not
  exist; the app only starts because `data/gschemas.compiled` is committed.
- **No working test target.** `bundle exec rake spec`, `bundle exec rspec` and
  `rspec` all fail; the root `Gemfile` does not resolve (`kettle-family`
  requires Ruby >= 4.0.0 against a gemspec floor of 3.4) and there is no
  `Gemfile.lock`. The only command that runs the suite is the long `rspec`
  incantation inside `.github/workflows/tests.yml`, which bypasses `.rspec`
  and `spec/spec_helper.rb`. `nix/Gemfile` carries neither `sqlite3` nor
  `rspec`, so the devShell cannot run it either.

## Blockers

Things that cannot be ported as upstream writes them, and why.

- **`DatabaseCacheModel` (`src/bobby/sqlite/cache.rs`) has no direct
  equivalent.** It subclasses GObject and implements the `Gio.ListModel`
  interface vfuncs `item`/`n_items`/`item_type`. ruby-gnome cannot implement a
  GObject interface's virtual functions from Ruby. The port uses a
  `Gio::ListStore` of a `type_register`ed `GLib::Object` subclass, filled
  eagerly. This costs the constant-memory browsing of very large tables and is
  the one real behavioural regression in the port (gap C-07). Chunk-on-scroll
  filling would narrow it; it would not restore the windowed cache.
- **`glib::BoxedAnyObject` has no Ruby equivalent.** Upstream boxes a plain
  Rust `Row` into a GObject to put it in a list model. The port carries the
  cell array on a `type_register`ed `GLib::Object` subclass instead.
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
