# Component parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `28bb3a5eec99ec3b5543f00e902cf10d00ba0fe9` |
| Units with parity | **11 / 16** |
| Stylesheet | neither side has one. Every class used is a GTK/libadwaita platform class, so the CSS axis collapses to attachment |
| Driven | yes — `nix develop` (GTK 4.22.4, libadwaita), `gtk4-broadwayd`, 86 checks over 22 steps, 4 screenshots |

## How this was checked

Steps 4 and 5 of the skill were actually performed, which contradicts
`FINDINGS.md`'s claim that "this machine has no GTK 4 or libadwaita … so the
app cannot be started at all here". Inside the port's own documented
environment:

```
nix develop → pkg-config --modversion gtk4 → 4.22.4
gtk4-broadwayd :N & ; env -u DISPLAY -u WAYLAND_DISPLAY \
  GDK_BACKEND=broadway BROADWAY_DISPLAY=:N ruby -Ilib <driver>
```

GTK 4.22 has no offscreen backend, so `gtk4-broadwayd` is what the
`ruby-gtk-testing` skill's "no Xvfb needed" line needs on this box. One extra
hack was required and is itself a finding: `nix/Gemfile` does not list
`sqlite3`, so `require "bobby"` fails in the devShell until the gem is put on
`RUBYLIB` by hand (gap **C-16** below).

The window, the three states, the dialogs and the actions were then driven and
asserted against upstream's source. Screenshots:

| Shot | What it shows |
|---|---|
| `.reports/shots/content-state.png` | content state: switcher `people`, title `test.db`, `id ◇` header, row numbers, em dashes for NULL, toast — **and the blob column rendering `AB` where upstream renders `2 BYTES`** |
| `.reports/shots/error-state.png` | error state: `Unable to Open File`, `dialog-error-symbolic`, markup-bolded `SQLite database`, the `Open...` pill |
| `.reports/shots/preferences-dialog.png` | the preferences dialog, matching upstream row for row |
| `.reports/shots/shortcuts-dialog.png` | the shortcuts dialog: Ctrl+O, F10, Ctrl+R, Ctrl+W, Ctrl+Q, Ctrl+C in two sections |

The empty state was photographed during the run and overwritten before it was
copied out. What it showed is recorded under **C-02**: `Browse Databases`, the
description with `SQLite files` correctly bolded, the `Open...` pill, and a
generic broken-image placeholder where `studio.planetpeanut.Bobby-symbolic`
should be.

The `Adw.Dialog`s present into their own surface, so they do not appear in the
parent window's render node; they were screenshotted as widgets instead. The
about dialog would not produce a render node at all and was verified by
property assertions only.

## Whole-app scan, before reading

| Axis | Upstream distinct | Port distinct | In upstream, not in port |
|---|---:|---:|---:|
| Widget types | 10 | 22 | 1 (`Gtk.Widget`, a downcast target — not a widget) |
| CSS classes | 6 | 6 | 0 |
| Signals | 12 | 13 | 3 (all scan artifacts) |
| Actions | 10 | 3 | 8 (all scan artifacts — names are constants) |

The action row is why the scan was not trusted: 7 of the port's 10 actions are
built from a `NAME` constant and never appear as a literal. All ten were
confirmed installed and accelerated by driving `has_action?` and
`get_accels_for_action` on the running application.

---

## Unit: application — `src/gtk/lib.rs` + `src/main.rs` + `src/app.rs` + `src/cli.rs` + `src/log.rs` → `lib/bobby/application.rb` + `app.rb` + `cli.rb` + `log.rb`

| Item | Up × | Port × | Behaviour | Text | Verdict |
|---|---:|---:|---|:-:|---|
| application object | 1 | 1 | ✓ id, `HANDLES_OPEN` | — | correspondence: `Gtk::Application` + `Adwaita.init` stands in for `Adw::Application`, which the Ruby bindings cannot build (`lib/bobby/application.rb:123`) |
| signal `open` | 1 | 1 | ✓ driven — reuses the empty window, then raises by path | — | parity |
| signal `activate` | 1 | 1 | ✓ driven | — | parity |
| 5 app actions | 5 | 5 | ✓ driven, all installed | — | parity |
| 5 accelerators | 5 | 5 | ✓ driven, all match after `<Primary>`→`<Control>` normalisation | — | parity |
| 3 settings watches | 3 | 3 | ✓ driven for `row-numbers` | — | parity |
| root refusal | 1 | 1 | ✓ `Cannot run as root`, exit 255 | — | parity |
| CLI `--help/--version/--deps/--env` | 4 | 4 | ✗ **gap C-01** | — | **gap** |

**C-01 — the CLI options cannot run without a display.** Upstream's `main()`
calls `cli_parse_args` before `gui_run()`, and `gtk_init` only runs inside
`app.run()`, so `bobby --version` prints and exits 0 on a headless box. The
port's `exe/bobby` does `require "bobby"`, and the Ruby `gtk4` gem calls
`gtk_init` at require time. Driven: with no display, `bobby --version` exits
**1** with a `Gtk::InitError` backtrace; with a display it prints
`bobby 0.1.0`. Upstream `src/main.rs:36-46`. Port `exe/bobby:5`,
`lib/bobby.rb:3`.

## Unit: window — `src/gtk/windows/window.rs` → `lib/bobby/window.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application window | 1 | 1 | ✓ `flat` (driven) | ✓ `win.close` installed (driven) | — | correspondence: `Gtk::ApplicationWindow` + a hidden titlebar for `Adw::ApplicationWindow`; recorded in `FINDINGS.md` |
| `Adw.ToolbarView` | 1 | 1 | — | ✓ `flat` → `raised_border` on content (driven both ways) | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | ✓ switcher start, menu end | — | parity |
| `Adw.StatusPage` (empty) | 1 | 1 | — | — | ✓ | parity — but see **C-02** |
| `Adw.StatusPage` (error) | 1 | 1 | — | — | ✓ | parity |
| `Adw.Banner` | 1 | 1 | — | ✗ action target differs | ✓ | **gap C-03** |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ `drop` | — | parity |

Messages: 6 upstream (`Bobby`, `Browse Databases`, `Drag and drop <b>SQLite
files</b> here`, `Unable to Open File`, `File has changed`, `Reload`), 6 in the
port, byte-identical (`lib/bobby/window.rb:48-57`). ✓
Driven: empty → content → reload → error all reached and asserted; the
`raised_border` switch, the banner's unrevealed state and the window title
(`test.db`, then `notadb.db`) all match.

**C-02 — the empty state's icon does not resolve.** Driven: the status page
renders the generic missing-image placeholder, not
`studio.planetpeanut.Bobby-symbolic`. The SVGs are committed under
`data/icons/hicolor/`, but nothing installs them into an icon theme — the
consequence of the "no install step" entry already in `FINDINGS.md`, now with
a picture of it.

**C-03 — the reload banner's button targets a different action.** Upstream
`src/gtk/windows/window.rs:350` sets `action_name = "app.reload"`, and no
`app.reload` action exists anywhere upstream, so upstream's banner button is
inert. The port points it at `win.reload`
(`lib/bobby/window.rb:214`), which works. The port is better; it is still a
behavioural divergence from the spec, it is recorded only in a class comment,
and it is not in `FINDINGS.md`.

**C-04 — the top-bar style is reset on leaving the content state.** The port
sets `toolbar_view.top_bar_style = :flat` in both `show_empty_state`
(`window.rb:117`) and `show_error_state` (`window.rb:127`). Upstream sets the
style to `RaisedBorder` on entering the content state and never sets it back,
so after content → error upstream keeps the raised border. Small, visible, and
unrecorded.

## Unit: content — `src/gtk/widgets/content.rs` → `lib/bobby/widgets/content.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Gtk.ColumnView` | 1 | 1 | — | ✓ all 8 construction properties driven | — | parity |
| `Gtk.ColumnViewColumn` | 1+N | 1+N | — | ✓ 6 for a 5-column table (driven) | — | parity |
| `Gtk.SignalListItemFactory` | 1+N | 1+N | — | ✓ `setup`, `bind` | — | parity |
| `Gtk.SingleSelection` | 1 | 1 | — | — | — | parity |
| `Gtk.GestureClick` | 1 | 1 | — | ✓ `pressed`, `BUTTON_SECONDARY` | — | parity |
| `Gtk.PopoverMenu` | 1 | 1 | — | ✓ `has_arrow=false`, `pointing_to` | — | parity |
| context `Gio.Menu` | 2 items | 2 items | — | ✓ `win.copy-val::r:c`, `win.copy-row` | ✓ `Copy`, `Copy Row` | parity |
| measuring `Gtk.Label` | 1 | 1 | ✓ `monospace` | — | — | parity |

Column sizing driven: `id ◇` title ✓, text column 192 ✓, blob column not
resizable ✓, last column expands ✓, index column visibility follows
`row-numbers` ✓ (and flips when the setting is written ✓).
Messages: 2 upstream, 2 in the port, byte-identical. ✓

## Unit: item — `src/gtk/widgets/item.rs` → `lib/bobby/widgets/item.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| index `Gtk.Label` | 1/row | 1/row | ✓ `dimmed`, `monospace` | — | — | parity |
| value `Gtk.Label` | 1/cell | 1/cell | ✗ `dimmed` not applied to blobs | — | — | **gap C-05** |

**C-05 — every BLOB cell is misclassified, misrendered and can crash the
bind handler.** This is the port's worst defect and it is not recorded
anywhere.

`Affinity.from_value` (`lib/bobby/sqlite/affinity.rb:56-63`) tests
`when SQLite3::Blob`, but the `sqlite3` gem returns blob columns as plain
`String` with `ASCII-8BIT` encoding, never as `SQLite3::Blob` — that class is
a write-side wrapper. Proven in the devShell:

```
classes:   [String, String, Float, NilClass]
encodings: ["ASCII-8BIT", "UTF-8", nil, nil]
blob cell: type=text  to_s="\xDE\xAD"  dimmed=false  tooltip="TEXT \xDE\xAD"
```

Against upstream (`src/bobby/sqlite/row.rs:72-78`, `affinity.rs` `Display`):

| | Upstream | Port |
|---|---|---|
| affinity | `BLOB(len, preview)` | `TEXT(raw bytes)` |
| cell text | `2 BYTES` | the raw bytes — visible as `AB` in `04-toast.png` |
| dimmed | yes | no |
| tooltip | `BLOB 41 42 …` | `TEXT AB` |
| column width | 128, fixed | 128, fixed (this half is fine — it reads the *declared* type) |

With bytes that are not valid UTF-8 the damage is worse than cosmetic:
`Gtk::Label#text=` raises `Encoding::UndefinedConversionError: "\xDE" from
ASCII-8BIT to UTF-8` inside `Item.write_text`
(`lib/bobby/widgets/item.rb:34`), aborting `bind` — so **a table containing a
binary blob does not render**. Captured backtrace:
`content.rb:225 → item.rb:103 → item.rb:120 → item.rb:34`.

`spec/bobby/sqlite/affinity_spec.rb:72` and `:120` pass only because they
construct `SQLite3::Blob.new` by hand, which no read path ever produces. The
suite is green and the feature is broken.

## Unit: switcher — `src/gtk/widgets/switcher.rs` → `lib/bobby/widgets/switcher.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.MenuButton` | 1 | 1 | — | ✓ tooltip `Tables` (driven) | ✓ | parity |
| `Gio.Menu` + 2 sections | 1+2 | 1+2 | — | — | ✓ `Views – N`, `Tables – N` | parity |
| menu item | 1/table | 1/table | — | ✓ `win.table::<index>` | ✓ underscore doubling | parity |

Driven on a 4-table database (1 view, 3 tables): 2 sections ✓, 1 item in
Views ✓, 3 in Tables ✓, label follows `switch_table` ✓.

Noted, not a gap: `Switcher#tables=` rebuilds the menu when a window is
reopened on a changed file; upstream reuses the first switcher forever and
only changes its label, so upstream shows a stale menu. The port is better.
Recorded only in a comment.

## Unit: main menu — `src/gtk/widgets/menu.rs` → `lib/bobby/widgets/menu.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.MenuButton` | 1 | 1 | — | ✓ icon, tooltip (driven) | ✓ | parity |
| `Gio.Menu` | 3 items | 3 items (driven) | — | ✓ three app actions | ✓ `Preferences`, `Keyboard Shortcuts`, `About Bobby` | parity |
| `app.open-menu` + `F10` | 1 | 1 | — | ✓ driven | — | parity |

Correspondence: upstream builds a `PopoverMenu::from_model` and hands it to the
button; the port sets `menu_model` and lets GTK build the same popover
(`lib/bobby/widgets/menu.rb:45`).

## Unit: open button — `src/gtk/widgets/button.rs` → `lib/bobby/widgets/button.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Button` | 2/window | 2/window | ✓ `pill`, `suggested-action` (driven) | ✓ | ✓ `Open...` | parity |

Correspondence: upstream connects `clicked` and walks window → application to
activate `open`; the port sets `action_name = 'app.open'`
(`lib/bobby/widgets/button.rb:24`), which routes identically and additionally
insensitises the button if the action ever goes missing.

## Unit: drop target — `src/gtk/widgets/drop_target.rs` → `lib/bobby/widgets/drop_target.rb`

| Item | Up × | Port × | Signals | Verdict |
|---|---:|---:|---|---|
| `Gtk.DropTarget` | 1 | 1 | ✓ `drop`, always true | parity |

Correspondence: upstream reaches the application through
`window.application()`; the port is handed it. Same `Application#open` entry
point. Not driven — broadway has no drag source.

## Unit: preferences dialog — `src/gtk/dialogs/preferences.rs` → `lib/bobby/dialogs/preferences.rb`

| Widget | Up × | Port × | Signals | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Adw.PreferencesDialog` | 1 | 1 | — | — | parity |
| `Adw.PreferencesPage` | 1 | 1 | — | ✓ `Preferences` | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | ✓ `Rows &amp; Columns`, `Appearance` | parity |
| `Adw.SwitchRow` | 2 | 2 | ✓ GSettings binding | ✓ `Row Numbers`, `Monospace Font` | parity |
| `Adw.ComboRow` | 2 | 2 | ✓ `notify::selected` | ✓ `Row Order`, `Column Separator`, subtitle | parity |
| `Gtk.StringList` | 2 | 2 | — | ✓ 6 choice labels | parity |

Messages: 11 upstream, 11 in the port, byte-identical including the escaped
ampersand. ✓ All 10 driven and screenshotted (`p-01`), rendering identically to
the structure upstream builds.

Correspondence: upstream reads the combo choices back out of the schema with
`SettingsSchemaSource`; the port keeps them in `Settings::CHOICES`
(`lib/bobby/settings.rb:44-47`). Same values, same order. The port's version
can drift from the schema where upstream's cannot — worth a test, not a gap.

## Unit: shortcuts dialog — `src/gtk/dialogs/shortcuts.rs` → `lib/bobby/dialogs/shortcuts.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | parity |
| `Adw.ShortcutsSection` | 2 | 2 | ✓ `General`, `Tables` | parity |
| `Adw.ShortcutsItem` | 6 | 6 | ✓ all 6 labels and accelerators | parity |

Driven and screenshotted (`s-01`): Ctrl+O, F10, Ctrl+R, Ctrl+W, Ctrl+Q,
Ctrl+C, in upstream's order. The commented-out `Jump To Row` is correctly
absent from both.

## Unit: about dialog — `src/gtk/dialogs/about.rs` → `lib/bobby/dialogs/about.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.AboutDialog` | 1 | 1 | ✓ | parity |

Driven: name `bobby` ✓, developer ✓, copyright ✓, `License::GPL_3_0` ✓, issue
url ✓. Upstream's `// TODO: from_appdata() if running in Flatpak?` is a TODO
on both sides.

## Unit: file dialog — `src/gtk/dialogs/file.rs` → `lib/bobby/dialogs/file.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Gtk.FileDialog` | 1 | 1 | — | parity |
| `Gtk.FileFilter` | 2 | 2 | ✓ `SQLite Databases`, `All Files` | parity |

Filters, mime types and patterns all match. Correspondence: upstream iterates
the returned list model calling `window_handle_open`; the port hands the list
to `Application#open`, the same entry point. Not driven — a modal portal
chooser cannot be driven headlessly.

## Unit: actions — `src/gtk/actions/*.rs` → `lib/bobby/actions/*.rb`

| Action | Up | Port | Accel | Driven | Verdict |
|---|:-:|:-:|---|---|---|
| `app.about` | ✓ | ✓ | — | installed ✓ | parity |
| `app.open` | ✓ | ✓ | ✓ `<Primary>o` | installed ✓ | parity |
| `app.preferences` | ✓ | ✓ | ✓ `<Primary>comma` | installed ✓ | parity |
| `app.quit` | ✓ | ✓ | ✓ `<Primary>q` | installed ✓ | parity |
| `app.shortcuts` | ✓ | ✓ | ✓ `<Primary>question` | installed ✓ | parity |
| `app.open-menu` | ✓ | ✓ | ✓ `F10` | installed ✓ | parity |
| `win.close` | ✓ | ✓ | ✓ `<Primary>w` | installed ✓ | parity |
| `win.reload` | ✓ | ✓ | ✓ `<Primary>r` | installed ✓, reload keeps table + row count ✓ | parity |
| `win.table` | ✓ | ✓ | — | installed ✓, switches table and label ✓ | parity |
| `win.copy-row` | ✓ | ✓ | ✓ `<Primary>c` | **fires, then throws** | **gap C-06** |
| `win.copy-val` | ✓ | ✓ | — | **fires, then throws** | **gap C-06** |

**C-06 — Copy copies nothing. Both copy actions raise.**
`Bobby::Util.copy_to_clipboard` (`lib/bobby/util.rb:27`) calls
`display.clipboard.set_text(text)`. `Gdk::Clipboard` in ruby-gnome has no
`set_text`. Driven, activating the real `win.copy-row` action on a loaded
table:

```
lib/bobby/util.rb:27:in 'block in Bobby::Util.copy_to_clipboard':
  undefined method 'set_text' for an instance of Gdk::Clipboard
```

The clipboard's actual surface is
`[:content, :content=, :read_text_async, :read_text_finish,
:read_texture_async, :read_texture_finish, :set, :set_content,
:set_property]` — the method wanted is `#set`. Upstream
`src/gtk/util.rs:copy_to_clipboard` works, and copying is half of what this app
is for: it is in the shortcuts dialog, the context menu and the metainfo's
feature list (`Copy rows or cells to the clipboard`).

Everything downstream of the clipboard call was verified with the method
stubbed, and is correct: the row is formatted with the separator preference,
the toast is added to the overlay, the cell value matches the `row:col` target,
and `win.copy-val` reaches the right cell.

Upstream behaviour that the port does reproduce, confirmed by reading:
`overlay.dismiss_all` before every toast, timeout 2, the 96-character cutoff
after which `win.copy-val` shows no toast at all, and the `tnum=1` Pango span.
The port additionally escapes markup in the toast title
(`lib/bobby/actions/win_copy_val.rb:28-34`) where upstream interpolates raw;
that is a fix, located, and it changes no msgid.

## Unit: sqlite backend — `src/bobby/sqlite/*.rs` → `lib/bobby/sqlite/*.rb`

| Item | Up | Port | Verdict |
|---|---|---|---|
| `Affinity` parse (declared type) | 5 rules, INT first | same, driven by the spec | parity |
| `Affinity` from a read value | 5 arms incl. blob | blob arm unreachable | **gap C-05** |
| `Column` / `PRAGMA table_info` | ✓ | ✓ | parity (`unique` hardcoded false on both) |
| `Table` / `TableName` / `has_row_id` | ✓ | ✓, driven (4 tables, 1 view, 1 WITHOUT ROWID) | parity |
| `Row#format_with` 4 separators | ✓ | ✓ | parity |
| `RowOrder` DESC default | ✓ | ✓ | parity |
| `Database` immutable URI, journal_mode probe, busy timeout, query_only, foreign_keys | ✓ | ✓, driven (error state reached on a non-database) | parity |
| `Database#data_version` | ✓ | ✓ | parity (unused on both) |
| `DatabaseCacheModel` paging | 256-row page, ±256 eviction, cached count | reads every row eagerly | **gap C-07** |

**C-07 — no lazy paging.** `lib/bobby/sqlite/cache.rb:56` fills a
`Gio::ListStore` with every row before the window appears, against upstream's
paged `gio::ListModel` (`src/bobby/sqlite/cache.rs`). Already admitted in
`FINDINGS.md` and in the class comment, in the right register. It stays a gap.

## Unit: util — `src/gtk/util.rs` → `lib/bobby/util.rb`

| Function | Up | Port | Verdict |
|---|---|---|---|
| `widget_by_name` | ✓ | — | correspondence: the port's widgets are memoized accessors, so there is nothing to search for. Located: `window.rb:186-258`, `content.rb:99-139` |
| `find_column_view` | ✓ | — | same correspondence. Located: `window.rb#content`, `content.rb#column_view` |
| `copy_to_clipboard` | ✓ | ✗ raises | **gap C-06** |

## Packaging and data — upstream root → port root

| Upstream | Port | Verdict |
|---|---|---|
| `data/studio.planetpeanut.Bobby.desktop` | identical | parity |
| `data/studio.planetpeanut.Bobby.gschema.xml` | identical | parity |
| `data/gschemas.compiled` | present | parity |
| `data/studio.planetpeanut.Bobby.metainfo.xml` | identical + one `<release>` | parity |
| `data/icons/**` (2 SVGs) | present, **installed nowhere** | **gap C-02** |
| `data/screenshots/*.png` (4) | absent; metainfo still points at upstream's | **gap C-08**, admitted in `FINDINGS.md` — but see the accountability report: they were takeable |
| `LICENSE.txt` (GPLv3) | **absent** | **gap C-09** |
| GPLv3 header on every source file | **absent from every `lib/**/*.rb`** | **gap C-10** |
| `meson.build`, `meson.options`, `data/meson.build`, `data/icons/meson.build` | absent — nothing installs anything | **gap C-11**, partly admitted |
| `studio.planetpeanut.Bobby.yml`, `.devel.yml` | absent | **gap C-12**, admitted |
| `.github/workflows/flatpak.yml` | absent | **gap C-13**, admitted |
| `build-aux/dist-vendor.sh` | absent | **gap C-14**, admitted |
| `.github/CONTRIBUTING.md` | absent | **gap C-15** |
| `info/release-steps.md` | absent | **gap C-15** |
| `.github/workflows/tests.yml` | present | parity |
| `README.md`, `Bobby.doap`, `.github/CODE_OF_CONDUCT.md`, `.github/FUNDING.yml` | present | parity |

**C-09 / C-10 — the port ships no licence.** Upstream carries `LICENSE.txt`
and a five-line GPLv3 header on all 34 `.rs` files. The port has neither, while
`bobby-rb.gemspec:18` declares `GPL-3.0-or-later` and the about dialog shows
`License::GPL_3_0`. A GPL app with no licence text is not a packaging nit.

**C-16 — the port cannot start in its own documented environment.**
`flake.nix:102-107` builds the runtime bundle from `nix/Gemfile`, whose comment
says it "holds the gemspec's runtime dependencies only" — it lists `adwaita`
and `gtk4` and omits `sqlite3`, which `bobby-rb.gemspec:121` declares and which
`lib/bobby/app.rb:3` and `lib/bobby/sqlite/database.rb:3` require at load time.
Driven:

```
$ nix develop --command ruby -Ilib -e 'require "bobby"'
cannot load such file -- sqlite3 (LoadError)
	from /home/nathan/src/github/ruby-gtk-project/Bobby-rb/lib/bobby.rb:3
```

`packages.default` uses the same `gems` derivation, so `nix build` produces a
`bobby` launcher that cannot start either. Everything driven in this report
needed `sqlite3` forced onto `RUBYLIB` by hand.

Minor, same file: `flake.nix:146` compiles schemas from `data/schemas/*.gschema.xml`,
a directory the port does not have — the port's schema is `data/studio.planetpeanut.Bobby.gschema.xml`.
That branch is dead; the app survives only because `data/gschemas.compiled` is
committed and `Settings::SCHEMA_DIR` points at it.

---

## Summary

| Unit | Verdict |
|---|---|
| application | **gap** (C-01) |
| window | **gap** (C-02, C-03, C-04) |
| content | parity |
| item | **gap** (C-05) |
| switcher | parity |
| main menu | parity |
| open button | parity |
| drop target | parity |
| preferences dialog | parity |
| shortcuts dialog | parity |
| about dialog | parity |
| file dialog | parity |
| actions | **gap** (C-06) |
| sqlite backend | **gap** (C-05, C-07) |
| util | **gap** (C-06) |
| packaging and data | **gap** (C-02, C-08 … C-16) |

**16 open gaps. C-05 and C-06 are the two that matter: the port cannot show a
binary blob and cannot copy anything to the clipboard, and neither is written
down anywhere in the repository.**
