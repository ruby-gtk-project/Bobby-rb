# Bobby — upstream component inventory

Upstream: `origin/main`, Rust + gtk-rs 4 / libadwaita.
Port: `ruby` branch, Ruby GTK4 / Libadwaita, house style per `.claude/skills/ruby-gtk`.

Bobby is a read-only SQLite browser: open a `.db` file (argument, file dialog or
drag-and-drop), pick a table or view from a header-bar menu button, and read its
rows in a `Gtk.ColumnView` with per-cell and per-row clipboard copy.

## What the scan found, and did not

There are **no `.ui` and no `.blp` files** upstream, no GResource manifest and no
`po/` catalogue. Every widget is built imperatively in Rust, so the declarative
shortcut in the `component-identification` skill does not apply and the whole
inventory comes from reading `src/`. The only translated strings in the tree are
four `<summary xml:lang=…>` lines in `data/studio.planetpeanut.Bobby.metainfo.xml`
(de, es, fr, pt); the UI itself is untranslated and hard-codes English literals.

Upstream has no widget subclasses at all. Every "component" is a free function
returning a widget (`window_new`, `content_new`, `main_menu_new`, …) and state is
smuggled through `gtk_widget_set_name` plus `widget_by_name` tree walks
(`src/gtk/util.rs`) and `window.set_data("db", …)`. The port replaces both with
ordinary memoized accessors on the owning Ruby object — that is the single biggest
structural difference, and it removes `src/gtk/util.rs`'s reason to exist.

## Port status

`lib/` on `ruby` holds three files: `lib/bobby.rb` (one `require_relative`),
`lib/bobby/application.rb` (a blank Adwaita window with a "not written yet"
`StatusPage`) and `lib/bobby/rb/version.rb`. Skeleton only — **no** user-facing
component below is implemented.

The port mirrors upstream's `src/` grouping under `lib/bobby/`
(`widgets/`, `dialogs/`, `actions/`, `sqlite/`), one upstream file to one `.rb`.
Upstream's own grouping is nested, so flat `lib/*.rb` (as in the
`gnome-contacts-rb` pilot, whose upstream `src/` is flat) would collide on names
like `close.rb`.

---

## Application and entry points

### `src/gtk/lib.rs` — the application object → `lib/bobby/application.rb`

| Widget / object | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `open`, `activate` | `HANDLES_OPEN` flag; `open` reuses a window whose widget name equals the path, else `window_handle_open` |
| `Gio.Settings` | 1 | — | `changed::row-numbers`, `changed::row-order`, `changed::monospace-font` | each re-renders the active window |

Installs the five app actions (`about`, `open`, `preferences`, `quit`,
`shortcuts`). **Present on the port, as a skeleton only** — it has the
`Gtk::Application` + window + `ToolbarView` + `HeaderBar` shell and nothing else.

Quirk: `Adwaita::Application` and `Adwaita::ApplicationWindow` are both listed
broken in the Ruby bindings (`references/adwaita-quirks.md`). The port must use
`Gtk::Application` + `Gtk::ApplicationWindow`; the current skeleton uses
`Adwaita::ApplicationWindow` and needs correcting.

### `src/main.rs`, `src/app.rs` → `lib/bobby/app.rb`

Not a widget. App identity (id, name, version), XDG/Flatpak path resolution,
`app_runs_as_root` refusal, `app_runs_in_terminal`, `app_deps` (SQLite version).
Entry point refuses to run as root.

### `src/cli.rs` → `lib/bobby/cli.rb`

Terminal front end: `--help`, `--version`, `--deps`, `--env`. Only parsed when
`TERM` is set.

### `src/log.rs` → `lib/bobby/log.rb`

`log` / `info` / `debug` / `debug_struct` / `error` / `error_and_exit`; dim ANSI
debug output gated on `DEBUG=1`, red `bobby error:` prefix, exit code 255.

### `src/gui.rs` → folded into `lib/bobby/application.rb`

A one-method `Gui` trait. No Ruby equivalent needed.

---

## The window and its three states

### `src/gtk/windows/window.rs` — the main window → `lib/bobby/window.rb`

One `AdwApplicationWindow` per opened file, 960×640, that swaps its
`ToolbarView` content between three mutually exclusive states.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `flat` | hosts `win.close`, and in content state `win.copy-row`, `win.copy-val`, `win.reload`, `win.table` | widget name doubles as state: `"1"` = empty, else the file path |
| `Adw.ToolbarView` | 1 | — | — | widget name `toolbar_view`; top-bar style `Flat` when empty, `RaisedBorder` with content |
| `Adw.HeaderBar` | 1 | — | — | widget name `header_bar`; menu button packed end, table switcher packed start |
| `Gtk.DropTarget` | 1 (controller) | — | `drop` | from `drop_target.rs` |
| `Adw.StatusPage` | 1 per state | — | — | empty state and error state (see below) |
| `Adw.ToastOverlay` | 1 | — | — | content state only; wraps banner + content |
| `Adw.Banner` | 1 | — | `action_name = app.reload` | title "File has changed", button "Reload", `Suggested` style; **never revealed** — upstream TODO, no file monitor exists |
| `Gtk.Box` (vertical) | 1 | — | — | banner above content; the table-switch action swaps its last child |

States, all three real components:

- **Empty** (`window_show_empty_state`) — title "Bobby", `StatusPage`
  icon `studio.planetpeanut.Bobby-symbolic`, title "Browse Databases",
  description "Drag and drop <b>SQLite files</b> here" (Pango markup),
  child = the open button. Window name set to `"1"`.
- **Error** (`window_show_error_state`) — title = file basename, `StatusPage`
  icon `dialog-error-symbolic`, title "Unable to Open File", description = the
  error string (which itself carries markup: "File is not a <b>SQLite
  database</b> or encrypted"), child = the open button.
- **Content** (`window_show_content_state`) — title = file basename; builds the
  switcher once and reuses it on later renders; selects the named table or the
  first one; stashes the `Database` on the window.

Behaviour that is not a widget but is part of the window:
`window_handle_open` (reuse a window already showing that path, else recycle an
empty window, else open a new one), `window_reload` (preserves scroll position
via `hadjustment`/`vadjustment` and an idle callback, and the currently selected
table read off the switcher's label), `window_toggle_row_numbers` (forces a
column redraw, then toggles column 0 visibility), `window_toggle_row_order` and
`window_toggle_monospace_font` (both just re-fire `win.reload`),
`window_change_content` (rebuilds the `ScrolledWindow` for another table).

`row_order_from_settings` maps `"newest-first"`/`"oldest-first"` to
`RowOrder::Descending`/`Ascending`.

### `src/gtk/windows/prelude.rs`

Re-exports only. No port file.

---

## Widgets

### `src/gtk/widgets/content.rs` — the table view → `lib/bobby/widgets/content.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | widget name `content`, `vexpand` |
| `Gtk.ColumnView` | 1 | — | — | rubberband off, focusable, `has_tooltip`, separators on both axes, `single_click_activate`, `tab_behavior = Cell`, not reorderable; grabs focus |
| `Gtk.SingleSelection` | 1 (type) | — | — | over `DatabaseCacheModel` |
| `Gtk.ColumnViewColumn` | 1 + N (repeater) | — | — | one per table column, plus a synthetic index column at position 0 |
| `Gtk.SignalListItemFactory` | 1 per column (repeater) | — | `setup`, `bind` | index column uses the index pair, others the cell pair |
| `Gtk.GestureClick` | 1 (controller) | — | `pressed` (secondary button) | picks the `Label` under the pointer to work out row + column |
| `Gio.Menu` | 1 (context menu) | — | — | 2 items: "Copy" → `win.copy-val::<row>:<col>`, "Copy Row" → `win.copy-row` |
| `Gtk.PopoverMenu` | 1 | — | — | `has_arrow(false)`, `pointing_to` the click point, parented on the gesture's widget |
| `Gtk.Label` | 1 (throwaway) | `monospace` | — | measures `"0"` via a Pango layout to size the index column |

Column sizing: index column fixed to `margin + (digits+2)·char_width + margin`,
not resizable, visible per the `row-numbers` setting; `BLOB` columns 128px and
not resizable; `TEXT` 192px; everything else 128px. Last column expands.
Primary-key columns get `◇` appended to the title.
`content_force_redraw` hides and re-shows every column to dodge a GTK separator
glitch. `get_row` reads a `Row` back out of the selection model.

### `src/gtk/widgets/item.rs` — the cell factories → `lib/bobby/widgets/item.rb`

Two components, one per factory pair.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Label` (index cell) | 1 per row (repeater) | `dimmed`, `monospace` | — | right-aligned, `margin_start`/`margin_end` 4, `margin_top` 1, single line; text = position+1; parent tooltip `"<n> / <total>"` |
| `Gtk.Label` (value cell) | 1 per row × column (repeater) | `numeric`, plus `monospace` when the `monospace-font` setting is on, plus `dimmed` **dynamically** for `NULL`, `NUMERIC(None)` and `BLOB` cells | — | `xalign 0`, `margin_start` 4, single line; widget name = column index, which the context-menu gesture reads back |

Cell tooltips are typed: `"<AFFINITY> <value>"`, `"NULL"`, or
`"BLOB <hex preview> …"`, prefixed `"◇ PRIMARY_KEY  "` on primary-key columns.
Every setter is guarded against GTK cell reuse (only write when the value
differs) — worth keeping in the port, it is a real performance measure.

### `src/gtk/widgets/menu.rs` — the main menu → `lib/bobby/widgets/menu.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | installs `app.open-menu`, accel `F10` | icon `open-menu-symbolic`, tooltip "Main Menu" |
| `Gio.Menu` | 1 | — | — | 3 items: "Preferences" → `app.preferences`, "Keyboard Shortcuts" → `app.shortcuts`, "About Bobby" → `app.about` |
| `Gtk.PopoverMenu` | 1 | — | — | `from_model` |

The `app.open-menu` action activates the button, i.e. F10 opens the menu.

### `src/gtk/widgets/switcher.rs` — the table switcher → `lib/bobby/widgets/switcher.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | items target `win.table::<index>` | widget name `switcher`, tooltip "Tables", label = current table name |
| `Gio.Menu` | 1 root + 2 sections | — | — | sections titled `"Views – <n>"` and `"Tables – <n>"`; one item per table (repeater), `_` doubled to escape mnemonics |

### `src/gtk/widgets/button.rs` — the open button → `lib/bobby/widgets/button.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → activates `app.open` | label "Open...", centre-aligned; the child of both status pages |

### `src/gtk/widgets/drop_target.rs` — drag and drop → `lib/bobby/widgets/drop_target.rb`

| Object | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.DropTarget` | 1 (controller) | `drop` | accepts `Gdk.FileList` with `DragAction::COPY`, hands the files to `Application#open`, always accepts |

---

## Dialogs

### `src/gtk/dialogs/preferences.rs` → `lib/bobby/dialogs/preferences.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | presented on the active window |
| `Adw.PreferencesPage` | 1 | — | — | title "Preferences", icon `org.gnome.Settings-system-symbolic` |
| `Adw.PreferencesGroup` | 2 | — | — | "Rows &amp; Columns", "Appearance" |
| `Adw.SwitchRow` | 2 | — | — | "Row Numbers" bound to `row-numbers`; "Monospace Font" bound to `monospace-font` |
| `Adw.ComboRow` | 2 | — | `notify::selected` | "Row Order" (`row-order`: Newest First / Oldest First); "Column Separator" (`column-separator`: Tabs / Spaces / Commas / Markdown, subtitle "Used when copying rows to the clipboard") |
| `Gtk.StringList` | 2 (type) | — | — | the combo models |

Combo rows are *not* `settings.bind`ed — the dialog reads the enum choices out of
the GSettings schema itself (`SettingsSchemaSource` → `schema.key(key).range()`)
and maps index ↔ string value by position. The port needs the same
index↔value mapping; it can hard-code the choice lists instead of reading the
schema range, which the Ruby bindings expose awkwardly.

### `src/gtk/dialogs/shortcuts.rs` → `lib/bobby/dialogs/shortcuts.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | presented on the active window |
| `Adw.ShortcutsSection` | 2 | "General", "Tables" |
| `Adw.ShortcutsItem` | 6 | Open File `<Primary>o`, Open Menu `F10`, Reload Window `<Primary>r`, Close Window `<Primary>w`, Quit `<Primary>q`; Copy Row `<Primary>c` |

(A "Jump To Row" `<Primary>l` item is commented out upstream — do not port it.)

### `src/gtk/dialogs/about.rs` → `lib/bobby/dialogs/about.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | icon/app name/developer "Hylke Bons"/version/website/issue URL `https://github.com/hbons/Bobby/issues`/copyright "Copyright © 2025–2026  Hylke Bons"/`License::Gpl30` |

### `src/gtk/dialogs/file.rs` → `lib/bobby/dialogs/file.rb`

| Widget | × | Notes |
|---|---:|---|
| `Gtk.FileDialog` | 1 | modal, `open_multiple`, every returned file goes through `window_handle_open` |
| `Gtk.FileFilter` | 2 | "SQLite Databases" — mime `application/x-sqlite3`, `application/vnd-sqlite3`; patterns `*.db`, `*.db3`, `*.sqlite`, `*.sqlite3`. And "All Files" — `*` |
| `Gio.ListStore` | 1 (type) | the filter list |

---

## Actions and accelerators

Ten actions. All are `Gio::SimpleAction`s created by a free function that also
sets the accel; the port installs them from the owning object instead. Each gets
its own file, mirroring upstream.

| Upstream | Action | Accel | Target | Does |
|---|---|---|---|---|
| `src/gtk/actions/app_about.rs` | `app.about` | — | `lib/bobby/actions/app_about.rb` | About dialog on the active window |
| `src/gtk/actions/app_open.rs` | `app.open` | `<Primary>o` | `lib/bobby/actions/app_open.rb` | File dialog |
| `src/gtk/actions/app_preferences.rs` | `app.preferences` | `<Primary>comma` | `lib/bobby/actions/app_preferences.rb` | Preferences dialog |
| `src/gtk/actions/app_quit.rs` | `app.quit` | `<Primary>q` | `lib/bobby/actions/app_quit.rb` | Quits |
| `src/gtk/actions/app_shortcuts.rs` | `app.shortcuts` | `<Primary>question` | `lib/bobby/actions/app_shortcuts.rb` | Shortcuts dialog |
| `src/gtk/widgets/menu.rs` | `app.open-menu` | `F10` | `lib/bobby/widgets/menu.rb` | Activates the menu button (installed by the menu, not an action file) |
| `src/gtk/actions/win_close.rs` | `win.close` | `<Primary>w` | `lib/bobby/actions/win_close.rb` | Closes the window |
| `src/gtk/actions/win_copy_row.rs` | `win.copy-row` | `<Primary>c` | `lib/bobby/actions/win_copy_row.rb` | Copies the selected row with the `column-separator` setting, then an `Adw.Toast` "Row N copied to clipboard", timeout 2, after `dismiss_all` |
| `src/gtk/actions/win_copy_val.rs` | `win.copy-val` | — | `lib/bobby/actions/win_copy_val.rb` | String param `"<row>:<col>"`; copies one cell; toast `‘value’ copied to clipboard` with `font_features='tnum=1'` markup, only when under 96 chars |
| `src/gtk/actions/win_reload.rs` | `win.reload` | `<Primary>r` | `lib/bobby/actions/win_reload.rb` | No-op on an empty window; else re-reads the database file |
| `src/gtk/actions/win_switch_table.rs` | `win.table` | — | `lib/bobby/actions/win_switch_table.rb` | **Stateful**, string state = table index; sets the switcher label and swaps the box's last child |

`Adw.Toast` (× 2, both from the copy actions) is a user-facing component that
lives only in these files.

`src/gtk/actions/prelude.rs` is re-exports only — no port file.

---

## Support, model and settings

| Upstream | Target | Kind | What |
|---|---|---|---|
| `src/gtk/util.rs` | `lib/bobby/util.rb` | backend | `widget_by_name` tree walk, `find_column_view`, `copy_to_clipboard` via `Gdk::Display.default.clipboard`. The two lookups should **not** be ported — memoized accessors replace them. Only the clipboard helper survives. |
| `src/bobby/sqlite/database.rs` | `lib/bobby/sqlite/database.rb` | backend | Read-only connection over the file URI with `immutable=1`; rejects non-SQLite/encrypted files by checking `PRAGMA journal_mode`; 3s busy timeout, `query_only`, `foreign_keys` |
| `src/bobby/sqlite/table.rs` | `lib/bobby/sqlite/table.rb` | model | `sqlite_master` query for tables and views, `has_row_id` from `WITHOUT ROWID`, `row_count`; `TableName` validates non-empty, no `sqlite_` prefix, alphanumeric/underscore only |
| `src/bobby/sqlite/column.rs` | `lib/bobby/sqlite/column.rb` | model | `PRAGMA table_info`; `Column` (id, name, affinity, primary_key, not_null, default, unique) and the `ColumnSeparator` enum (tabs/spaces/commas/markdown) |
| `src/bobby/sqlite/row.rs` | `lib/bobby/sqlite/row.rb` | model | Paged `SELECT` with `rowid` ordering when available, else `LIMIT/OFFSET`; `Row#format_with` for the four separators (Markdown wraps in pipes); `RowOrder` → `DESC`/`ASC`; 8-byte hex blob preview |
| `src/bobby/sqlite/affinity.rs` | `lib/bobby/sqlite/affinity.rb` | model | SQLite type-affinity parsing, display (`—` for NULL, `<n> BYTES` for blobs) and `to_type_string` |
| `src/bobby/sqlite/cache.rs` | `lib/bobby/sqlite/cache.rb` | backend | `DatabaseCacheModel`: a custom `Gio::ListModel` paging 256 rows around the requested index and evicting outside a ±256 guard. See blockers. |
| `data/studio.planetpeanut.Bobby.gschema.xml` | `lib/bobby/settings.rb` | backend | 4 keys: `row-numbers` (b, true), `row-order` (s, newest-first/oldest-first, default newest-first), `column-separator` (s, tabs/spaces/commas/markdown, default tabs), `monospace-font` (b, false) |

`src/bobby/tests/` holds one Rust test module (`test_sqlite_affinity.rs`) — the
affinity parser. It belongs in `spec/`, not `lib/`.

---

## Blockers and things that cannot be ported as written

1. **`DatabaseCacheModel` — a custom `Gio::ListModel` implemented in Ruby.**
   Upstream subclasses `GObject` and implements the `Gio.ListModel` interface's
   `item`/`n_items`/`item_type` vfuncs. ruby-gnome cannot implement a GObject
   *interface*'s virtual functions from Ruby, so the windowed row cache has no
   direct equivalent. Fallback: a `Gio::ListStore` of a registered Ruby
   `GLib::Object` subclass, filled eagerly (or in chunks on scroll). That costs
   the constant-memory browsing of very large tables — the one real behavioural
   regression in the port, and it should be stated in the port's README.
2. **`glib::BoxedAnyObject`.** Upstream boxes a plain Rust `Row` into a GObject
   to put it in a list model. Ruby has no `BoxedAnyObject`; rows must be carried
   by a `type_register`ed `GLib::Object` subclass holding the cell array.
3. **`immutable=1` URI + `OpenFlags::SQLITE_OPEN_URI`.** The `sqlite3` gem opens
   by path with a `readonly:` option and does not expose URI open flags; the
   immutable optimisation and possibly the URI form need verifying against the
   gem in the dev shell. `PRAGMA query_only` / `foreign_keys` / `busy_timeout`
   are all reachable through plain `execute`.
4. **`window.set_data("db", …)` / `widget_by_name` / `find_column_view`.**
   Unsafe GObject user data and widget-tree walks exist only because upstream
   has no widget subclasses. Not portable and not wanted — Ruby memoized
   accessors hold the database and the `ColumnView` directly. Anything upstream
   derives from `widget_name` (which window shows which path, which state a
   window is in, which column a label belongs to) needs an explicit Ruby
   attribute instead.
5. **`Adwaita::ShortcutsDialog` / `ShortcutsSection` / `ShortcutsItem`.** New in
   libadwaita 1.9. Whether the installed Ruby bindings expose them must be
   checked before writing `dialogs/shortcuts.rb`; the fallback is
   `Gtk::ShortcutsWindow`, which has a different widget tree.
6. **`Adwaita::Application` / `Adwaita::ApplicationWindow`** are broken in the
   Ruby bindings. The port uses `Gtk::Application` + `Gtk::ApplicationWindow`
   with Adwaita widgets inside; `lib/bobby/application.rb` currently uses
   `Adwaita::ApplicationWindow` and must be changed.
7. **Flatpak, meson, GResource, icons and the `.desktop`/`.metainfo.xml`
   install.** Packaging, not components. The gem ships no GResource, and the
   GSettings schema must be compiled and on `GSETTINGS_SCHEMA_DIR` for the app
   to start at all — upstream has the same unresolved TODO in `src/app.rs`.
8. **No translation parity work exists.** No `po/`, no gettext calls, no
   `_()`-style wrappers anywhere upstream; strings are English literals in Rust.
   The port should keep literals too rather than invent a catalogue.
9. **`Adw.Banner` is dead code.** It is built but never revealed, because no
   file monitor was ever written (`// .revealed(true) // TODO`). Port the widget
   for parity; do not invent the file-watching behaviour.
