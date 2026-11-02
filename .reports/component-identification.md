# Component identification — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `9a3ce26f5edc81fdd0614ab6e3523ff09305463d` |
| Declarative UI (Step 1) | **none on either side** — no `.ui`, no `.blp`, no GResource, no `.css` |
| Units | 16 |

## Step 1 — there is no declarative UI to read

```
find <upstream> <port> \( -name '*.blp' -o -name '*.ui' -o -name '*.css' \) → empty
```

Upstream is gtk-rs and builds every widget in code with the builder pattern;
the port is the house style and builds every widget as a memoized accessor. So
there are no `<template>` roots to hand over the unit list, and the unit list
below was derived the fallback way: one unit per upstream source file that
builds a top-level widget, plus one for the application class, plus one for the
packaging and data files that no widget class owns.

Both trees also have **no stylesheet**. Every CSS class either app attaches is
a GTK or libadwaita platform class (`flat`, `pill`, `suggested-action`,
`dimmed`, `monospace`, `numeric`), so the CSS axis collapses to attachment and
there is nothing to diff.

## Step 2/3 — the scan, on both trees

```
component-scan.sh <upstream> → 70 rows
component-scan.sh <port>     → 77 rows
```

| Axis | Upstream distinct | Port distinct | Only upstream | Only port |
|---|---:|---:|---|---|
| `widget` | 10 | 22 | `Gtk.Widget` | 13 Adwaita/Gtk names |
| `controller` | 0 | 2 | — | `Gtk.DropTarget`, `Gtk.GestureClick` |
| `type` | 5 | 14 | `Adw.BannerButtonStyle`, `Gtk.ListItem` | 11 names |
| `css` | 6 | 6 | — | — |
| `signal` | 12 | 14 | `clicked`, `notify-local` | `changed::`, `destroy`, `index-factory`, `value-factory` |
| `action` | 10 | 3 | 8 | `s` |

**The scan is wrong on five of six axes here, in a way worth writing down,
because every one of these is a scanner artifact and not a finding.** Reading
was what produced the inventory below.

- **The `widget` row is inverted.** Rust `use gtk4::{Button, Label, …}` puts the bare name in scope, so `Button::builder()` carries no `Gtk.` prefix and the regex never matches it. The port writes `Gtk::Button` in full. So upstream's 10 against the port's 22 is a measure of Rust's import style, not of missing widgets: upstream builds `Gtk.Button`, `Adw.StatusPage`, `Adw.ToolbarView`, `Adw.HeaderBar`, `Adw.ToastOverlay`, `Adw.Banner`, `Gtk.PopoverMenu` and the rest, all of which the scan assigns only to the port.
- **`Gtk.Widget` is a downcast target** (`window.upcast_ref::<Widget>()`), not a widget on screen. Struck.
- **`Gtk.ListItem` is `<child>` plumbing** and `Adw.BannerButtonStyle` is an enum. Both struck, as Step 4 requires.
- **`Gtk.License`, `Gtk.PickFlags` are enums**; `Adw.Toast`, `Gtk.FileFilter`, `Gtk.FileDialog`, `Gtk.StringList`, `Gtk.SignalListItemFactory`, `Gtk.IconTheme`, `Gtk.Application` are types, not widgets. `Adw.ShortcutsSection`/`Adw.ShortcutsItem` are the dialog's model objects. The classifier puts all of them in the `type` stream, which is why they never reach the widget count.
- **The `action` stream is the least trustworthy, exactly as the skill warns.** Seven of the port's ten actions are built from a `NAME` constant (`Gio::SimpleAction.new(NAME, …)`) and never appear as a literal, so `app.preferences`, `app.quit`, `app.shortcuts`, `app.open-menu`, `win.close`, `win.copy-row` read as upstream-only. All ten were confirmed installed by driving `has_action?` and `get_accels_for_action` on the running application (drive steps 3, 56, 67, 83). The `s` row is the `GLib::VariantType.new('s')` argument of `win.copy-val`, not an action.
- **`clicked` and `notify-local`** are real correspondences, not gaps: the open button connects `clicked` upstream and sets `action_name = 'app.open'` in the port (`lib/bobby/widgets/button.rb:24`), and `connect_notify_local(Some("selected"))` upstream is `notify::selected` in the port — the port narrowing the connection, which the skill calls strictly better.
- **`index-factory` and `value-factory`** are not signals; they are words inside method names the regex caught.

Three actions in upstream's stream exist nowhere in either running app:
`win.open-table-menu` and `win.copy-rows::{}` are commented out upstream, and
`app.reload` is the reload banner's target with no action behind it. See the
component-parity report, gap C-03.

## The inventory

One section per unit, in the order a user meets them.

### `src/gtk/lib.rs` + `src/main.rs` + `src/app.rs` + `src/cli.rs` + `src/log.rs` + `src/gui.rs` — the application

| Item | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `open`, `activate` | `HANDLES_OPEN` is what routes a file argument to `open` |
| app actions | 5 | — | `app.about`, `app.open`, `app.preferences`, `app.quit`, `app.shortcuts` | installed in `gui_run` |
| accelerators | 5 | — | `<Primary>o`, `<Primary>comma`, `<Primary>q`, `<Primary>question`, `F10` | `F10` belongs to `app.open-menu`, installed by the menu widget |
| GSettings watches | 3 | — | `changed::row-numbers`, `changed::row-order`, `changed::monospace-font` | row-numbers toggles in place; the other two reload |
| CLI options | 4 | — | — | `--help`, `--version`, `--deps`, `--env`, read off `args[1]` only |
| root refusal | 1 | — | — | `Cannot run as root`, exit 255 |
| log levels | 6 | — | — | `log`, `info`, `debug`, `debug_struct`, `error`, `error_and_exit` |

Repeaters: the `open` handler loops over the file list. Conditional: the CLI
runs only when `TERM` is set; the `(Flatpak)` version suffix only when
`FLATPAK_ID` is.

### `src/gtk/windows/window.rs` — one database, or one window waiting for one

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `flat` | `win.close` installed | 960×640; `widget_name` carries the open path, or `"1"` when empty |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` Flat at build, RaisedBorder on entering content, never lowered |
| `Adw.HeaderBar` | 1 | — | — | switcher packed start, main menu packed end |
| `Adw.StatusPage` (empty) | 1 | — | — | `studio.planetpeanut.Bobby-symbolic`, `Browse Databases`, `Drag and drop <b>SQLite files</b> here` |
| `Adw.StatusPage` (error) | 1 | — | — | `dialog-error-symbolic`, `Unable to Open File`, description is the error, rendered as markup |
| `Adw.Banner` | 1 | — | `app.reload` | `File has changed` / `Reload`, button style Suggested, **never revealed** — the file monitor is unwritten upstream |
| `Gtk.Box` (vertical) | 1 | — | — | banner above the table |
| `Adw.ToastOverlay` | 1 | — | — | the window's content in the content state |
| `Gtk.DropTarget` | 1 | — | `drop` | a controller, compared on the signal axis |
| open button | 2/window | `pill`, `suggested-action` | `app.open` | one on each status page |

Three states, not one widget tree: empty, error, content. Conditional: the
switcher is built on first entry to the content state and reused. Repeater: one
`win.table::<i>` per table.

### `src/gtk/widgets/content.rs` — the table

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `widget_name = "content"`, vexpand |
| `Gtk.ColumnView` | 1 | — | — | 8 construction properties: no rubberband, focusable, has_tooltip, not reorderable, column and row separators, single-click activate, tab behaviour Cell |
| `Gtk.ColumnViewColumn` | 1 + N | — | — | index column fixed and not resizable; BLOB 128 fixed and not resizable; TEXT 192; else 128; last column expands |
| `Gtk.SignalListItemFactory` | 1 + N | — | `setup`, `bind` | one per column |
| `Gtk.SingleSelection` | 1 | — | — | the model |
| `Gtk.GestureClick` | 1 | — | `pressed`, `BUTTON_SECONDARY` | a controller |
| `Gtk.PopoverMenu` | 1/click | — | — | `has_arrow = false`, `pointing_to` the click |
| context `Gio.Menu` | 2 items | — | `win.copy-val::r:c`, `win.copy-row` | `Copy`, `Copy Row` |
| measuring `Gtk.Label` | 1 | `monospace` | — | asks Pango for the digit advance so the index column can be sized |

Repeaters: one column, one factory and one `ColumnViewColumn` per database
column, plus the reserved index column at position 0. `content_force_redraw`
hides and re-shows every column — upstream's own HACK comment.

### `src/gtk/widgets/item.rs` — the cells

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| index `Gtk.Label` | 1/row | `dimmed`, `monospace` | — | row number, halign End, margins 4/4/1, single line; tooltip `n / total` on the **parent** |
| value `Gtk.Label` | 1/cell | `numeric`, `monospace` (when the preference is on), `dimmed` (dynamic) | — | xalign 0, margin-start 4; `widget_name` is the column index, which is how the context menu learns which cell was clicked |

Dynamic CSS: `dimmed` is added for `NULL`, a value-less `NUMERIC` and every
`BLOB`, and removed otherwise — one class, both values, recomputed on every
bind. Tooltip is prefixed `◇ PRIMARY_KEY  ` on a key column. Every write
re-reads the current value first, because a `ColumnView` recycles cells.

### `src/gtk/widgets/switcher.rs` — the table picker

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | tooltip `Tables` | `widget_name = "switcher"`; label is the open table's name |
| `Gio.Menu` + 2 sections | 1 + 2 | — | — | `Views – N`, `Tables – N` |
| menu item | 1/table | — | `win.table::<index>` | underscores doubled to dodge the mnemonic |

Repeater: one item per table, filed into the view or the table section by
`is_view()`, indexed against the full list.

### `src/gtk/widgets/menu.rs` — the hamburger

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | `open-menu-symbolic`, tooltip `Main Menu` | |
| `Gtk.PopoverMenu` | 1 | — | — | `from_model` |
| `Gio.Menu` | 3 items | — | `app.preferences`, `app.shortcuts`, `app.about` | `Preferences`, `Keyboard Shortcuts`, `About Bobby` |
| `app.open-menu` + `F10` | 1 | — | activates the button | exists only so the keyboard can open it |

### `src/gtk/widgets/button.rs` — the open pill

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` | 1/call | `pill`, `suggested-action` | `clicked` → walks window → application → `activate_action("open")` | label `Open...`, halign Center |

Called twice per window, from both status pages. Counting the call sites rather
than the constructor is the Step 4 rule that applies here.

### `src/gtk/widgets/drop_target.rs`

| Item | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.DropTarget` | 1 | `drop`, returns true always | `FileList` type, `DragAction::COPY`; hands the list to `Application::open` |

### `src/gtk/dialogs/preferences.rs`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | `Preferences`, `org.gnome.Settings-system-symbolic` |
| `Adw.PreferencesGroup` | 2 | — | — | `Rows &amp; Columns` (markup, escaped), `Appearance` |
| `Adw.SwitchRow` | 2 | — | GSettings `bind` | `Row Numbers`, `Monospace Font` |
| `Adw.ComboRow` | 2 | — | `notify::selected` | `Row Order`, `Column Separator` + subtitle |
| `Gtk.StringList` | 2 | — | — | 2 + 4 choice labels |

The combos cannot be bound: a position is not a string, so the index is
resolved against the schema's `<choices>` both ways.

### `src/gtk/dialogs/shortcuts.rs`

| Widget | × | Text |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | — |
| `Adw.ShortcutsSection` | 2 | `General`, `Tables` |
| `Adw.ShortcutsItem` | 6 | Open File/Open Menu/Reload Window/Close Window/Quit, Copy Row |

Conditional, in the sense that it is commented out on both sides:
`Jump To Row` / `<Primary>l`.

### `src/gtk/dialogs/about.rs`

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | icon, name, `Hylke Bons`, version, website, issue url, `Copyright © 2025–2026  Hylke Bons`, `License::Gpl30` |

### `src/gtk/dialogs/file.rs`

| Widget | × | Text |
|---|---:|---|
| `Gtk.FileDialog` | 1 | modal, `open_multiple` |
| `Gtk.FileFilter` | 2 | `SQLite Databases` (2 mime types, 4 patterns), `All Files` (`*`) |

### `src/gtk/actions/*.rs` — ten actions

| Action | Stateful | Parameter | Accel |
|---|---|---|---|
| `app.about` | no | — | — |
| `app.open` | no | — | `<Primary>o` |
| `app.preferences` | no | — | `<Primary>comma` |
| `app.quit` | no | — | `<Primary>q` |
| `app.shortcuts` | no | — | `<Primary>question` |
| `app.open-menu` | no | — | `F10` |
| `win.close` | no | — | `<Primary>w` |
| `win.reload` | no | — | `<Primary>r` |
| `win.copy-row` | no | — | `<Primary>c` |
| `win.copy-val` | no | `s` (`"row:col"`) | — |
| `win.table` | **yes** | `s` (index) | — |

Repeater: `win.table` is one action whose state is the index of the open table.
Its names are all literals upstream and all constants in the port, which is why
the scan's action stream disagrees with reality by eight rows.

### `src/bobby/sqlite/*.rs` — the backend, no widgets

`Affinity` (6 variants, a declared-type parser, a value wrapper, a Display and
a type name), `Column` + `ColumnSeparator` (4), `Table` + `TableName`
(validated, three-valued `has_row_id`), `Row` + `RowOrder` (2) + `format_with`
(4 separators), `Database` (immutable URI, journal-mode probe, busy timeout,
`query_only`, `foreign_keys`, `data_version`), `DatabaseCacheModel` (a
`Gio.ListModel` with a 256-row page and ±256 eviction).

### `src/gtk/util.rs`

`widget_by_name` and `find_column_view` are tree walks that exist only because
the window is built by free functions holding no references — both marked for
replacement upstream. `copy_to_clipboard` is real behaviour.

### Packaging and data — no widget class owns these

`data/studio.planetpeanut.Bobby.desktop`, `.gschema.xml` (4 keys, 2 with
`<choices>`), `.metainfo.xml` (3 screenshots, 3 captions, 4 localised
summaries, 11 localised keywords, 8 releases), `data/gschemas.compiled`,
`data/icons/**` (2 SVGs), `data/screenshots/*.png` (4), `LICENSE.txt`,
`meson.build`, `meson.options`, `data/meson.build`, `data/icons/meson.build`,
both Flatpak manifests, `build-aux/dist-vendor.sh`,
`.github/workflows/flatpak.yml`, `.github/workflows/tests.yml`,
`.github/CONTRIBUTING.md`, `.github/CODE_OF_CONDUCT.md`, `.github/FUNDING.yml`,
`info/release-steps.md`, `README.md`, `Bobby.doap`, `Cargo.toml`,
`Cargo.lock`, `.cargo/config.toml`.

## Port side, same scan, same reading

The port's file mapping is 1→1 for every upstream source file and is in
`PORTING.md`'s architecture table. The port adds four files with no upstream
file opposite them, and each is explained rather than listed as an extra:

| Port file | What upstream block it stands for |
|---|---|
| `lib/bobby/settings.rb` | the `gio::Settings::new("studio.planetpeanut.Bobby") // TODO` repeated at six call sites, factored into one object |
| `lib/bobby/preflight.rb` | the half of `src/main.rs` that runs before `gui_run()` |
| `lib/bobby/icons.rb` | `data/icons/meson.build`'s install step, as a runtime theme-path registration |
| `lib/bobby/rb/version.rb` | `CARGO_PKG_VERSION` |

The port has **no** `.ui`, `.blp` or `.css` file, which is the house style
rather than an omission, and none of its widgets is built from a template.

## Rules check

- Every widget above carries its CSS classes and its signals. ✓
- No scan row was struck without opening the file. ✓
- Dynamic classes are listed with every value they take (`dimmed` on/off,
  `monospace` conditional on the preference). ✓
- Handlers are named where a widget's handler is the only thing it does
  (`content_clicked`, `context_menu_open`, `window_handle_open`). ✓
