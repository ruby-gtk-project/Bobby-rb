# Component identification — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe`, Rust + gtk-rs 4 / libadwaita |
| Port | `ruby` branch, Ruby GTK4 / Libadwaita |
| Scans | `component-scan.sh`: upstream 70 rows, port 73 rows |
| Declarative UI | **none on either side** — no `.ui`, no `.blp`, no GResource |

This supersedes `.reports/component-inventory.md`, which was written when `lib/`
held three skeleton files. `lib/` now holds 35 files and 3,171 lines.

## What the scan can and cannot see here

Step 1 of the skill does not apply: upstream has no declarative UI, so every
widget is built imperatively in Rust and the whole inventory comes from reading
`src/`. Both inventories below are reading-derived; the TSVs are a cross-check.

Two known distortions in the TSVs, both confirmed by reading:

- **The upstream widget stream is under-reported.** Rust multi-line
  `use libadwaita::{ StatusPage, ToastOverlay, ToolbarView, ... }` blocks do not
  match the scan's regexes, so `Adw.StatusPage`, `Adw.ToolbarView`,
  `Adw.HeaderBar`, `Adw.ToastOverlay`, `Adw.PreferencesDialog`,
  `Adw.ShortcutsDialog` and friends produce no upstream rows at all despite
  being built in `window.rs`, `preferences.rs` and `shortcuts.rs`.
- **The port action stream is under-reported** (3 rows against upstream's 10).
  Every port action name is assembled from a constant —
  `set_accels_for_action("win.#{NAME}", ACCELS)` — which is exactly the case the
  skill flags as the least trustworthy stream. Read off the install sites below.

The **CSS axis is the one stream that compares literally**, and it matches
exactly on both sides: `dimmed` ×3, `flat` ×1, `monospace` ×3, `numeric` ×1,
`pill` ×1, `suggested-action` ×1. Neither side ships a `.css` file; every class
is an Adwaita stock class.

Upstream has **no widget subclasses**. Every component is a free function
returning a widget (`window_new`, `content_new`, `main_menu_new`) and state is
smuggled through `gtk_widget_set_name` plus `widget_by_name` tree walks
(`src/gtk/util.rs`) and `window.set_data("db", …)`. The port replaces both with
memoized accessors on the owning Ruby object.

## File mapping

| Upstream | Port |
|---|---|
| `src/main.rs` + `src/app.rs` | `lib/bobby/app.rb` + `Application#start` |
| `src/cli.rs` | `lib/bobby/cli.rb` |
| `src/log.rs` | `lib/bobby/log.rb` |
| `src/gui.rs` (trait) | — (one-method trait; `Application#build`/`#run`) |
| `src/gtk/lib.rs` | `lib/bobby/application.rb` |
| `src/gtk/util.rs` | `lib/bobby/util.rb` (`copy_to_clipboard` only) |
| `src/gtk/windows/window.rs` | `lib/bobby/window.rb` |
| `src/gtk/widgets/{button,content,drop_target,item,menu,switcher}.rs` | `lib/bobby/widgets/*.rb` |
| `src/gtk/dialogs/{about,file,preferences,shortcuts}.rs` | `lib/bobby/dialogs/*.rb` |
| `src/gtk/actions/*.rs` (10) | `lib/bobby/actions/*.rb` (10) |
| `src/bobby/sqlite/*.rs` (6) | `lib/bobby/sqlite/*.rb` (6) |
| `data/*.gschema.xml` | `data/*.gschema.xml` (byte-identical) + `lib/bobby/settings.rb` |
| `data/*.metainfo.xml` | **absent** |
| `data/*.desktop` | **absent** |
| `data/icons/**` (2 SVG) | **absent** |
| `data/screenshots/**` (4 PNG) | **absent** |
| `studio.planetpeanut.Bobby{,.devel}.yml` (Flatpak) | **absent** |
| `Bobby.doap` | **absent** |
| `meson.build`, `meson.options`, `build-aux/dist-vendor.sh` | — (gem build) |

Port files with no upstream file opposite them, each explained:
`lib/bobby/settings.rb` (upstream builds a fresh `gio::Settings` at nine call
sites with a `// TODO` beside each; the port factors them into one object) and
`lib/bobby/sqlite/cache.rb`'s `RowObject` (stands in for upstream's
`glib::BoxedAnyObject`).

---

## Application and entry points

### `src/gtk/lib.rs` → `lib/bobby/application.rb`

| Widget / object | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` → `Gtk::Application` | 1 | — | `open`, `activate` | `HANDLES_OPEN`; `open` re-presents a window already showing that path |
| `Gio.Settings` | 1 | — | `changed::row-numbers`, `changed::row-order`, `changed::monospace-font` | each acts on the active window |

Actions installed: `app.about`, `app.open`, `app.preferences`, `app.quit`,
`app.shortcuts` — all five present
(`lib/bobby/application.rb:97-105`, `actions/app_*.rb`).

Repeaters: the window list (`#windows`), one entry per open file. Conditional:
none. Upstream's identity lookup is a `widget_name == path` scan over
`app.windows()`; the port's is `windows.find { |w| w.key == path }`.

### `src/main.rs`, `src/app.rs`, `src/cli.rs`, `src/log.rs` → `lib/bobby/{app,cli,log}.rb`

Not widgets. Four CLI options (`--help`, `--version`, `--deps`, `--env`), the
root refusal, the `DEBUG=1` dim-line logger, exit 255. All present.

---

## The window

### `src/gtk/windows/window.rs` → `lib/bobby/window.rb` — one database, or one window waiting for one

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `flat` | `destroy` (port only) | 960×640; **port uses `Adwaita::ApplicationWindow`, which the `ruby-gtk` skill lists as broken** |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` is state: `flat` → `raised_border` once a table is up |
| `Adw.HeaderBar` | 1 | — | — | `pack_start` switcher, `pack_end` main menu |
| `Adw.StatusPage` | 2 | — | — | empty state and error state |
| `Adw.ToastOverlay` | 1 | — | — | content state only; both copy toasts land here |
| `Gtk.Box` (vertical, 0) | 1 | — | — | banner above content |
| `Adw.Banner` | 1 | — | `action_name` | "File has changed" / "Reload", `suggested`. **Never revealed on either side** |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` | `Gdk::FileList`, `:copy` |

Actions installed on the window: `win.close` always; `win.copy-row`,
`win.copy-val`, `win.reload`, `win.table` once content exists. All five present.

Three states, all three present: `show_empty_state`, `show_error_state`,
`show_content_state`. Repeaters: the switcher's menu items, one per table/view.

### `src/gtk/widgets/button.rs` → `lib/bobby/widgets/button.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `action_name = "app.open"` | `halign: center`. Upstream connects `clicked` and walks window → application by hand; the port sets the action name instead |

Instantiated twice by the port (`empty_button`, `error_button`) because each
`Adw.StatusPage` needs its own child; upstream calls `button_open_new(window)`
twice for the same reason.

### `src/gtk/widgets/menu.rs` → `lib/bobby/widgets/menu.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | `menu_model` | `open-menu-symbolic`, tooltip "Main Menu" |
| `Gio.Menu` | 1 | — | — | 3 items: Preferences → `app.preferences`, Keyboard Shortcuts → `app.shortcuts`, About Bobby → `app.about` |

Installs `app.open-menu` bound to **F10**, whose only job is to pop the button
open. Present on both.

### `src/gtk/widgets/switcher.rs` → `lib/bobby/widgets/switcher.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | `menu_model` | label = open table, tooltip "Tables" |
| `Gio.Menu` | 3 | — | — | root + "Views – n" section + "Tables – n" section |

Repeater: one item per table, targeting `win.table::<index>` where the index is
the position in the **full** list, not the section. Underscores doubled against
GMenu mnemonics on both sides.

### `src/gtk/widgets/content.rs` → `lib/bobby/widgets/content.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | `vexpand` |
| `Gtk.ColumnView` | 1 | — | — | rubberband off, focusable, has-tooltip, not reorderable, column+row separators, single-click-activate, `tab_behavior: cell` |
| `Gtk.ColumnViewColumn` | n+1 | — | — | repeater: one per table column, plus a reserved index column at 0 |
| `Gtk.SignalListItemFactory` | n+1 | — | `setup`, `bind` | index factory for column 0, value factory for the rest |
| `Gtk.SingleSelection` | 1 | — | — | over the row model |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` | `BUTTON_SECONDARY` → context menu |
| `Gtk.PopoverMenu` | 1 per click | — | — | `has_arrow: false`, pointing at the click |
| `Gio.Menu` (context) | 1 per click | — | — | 2 items: Copy → `win.copy-val::<row>:<col>`, Copy Row → `win.copy-row` |

Conditional sizing, all present: index column fixed to a Pango-measured digit
width and not resizable; BLOB columns 128 and not resizable; TEXT 192; the rest
128; last column expands. Index column visibility follows `row-numbers`.

### `src/gtk/widgets/item.rs` → `lib/bobby/widgets/item.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Label` (index cell) | 1 | `dimmed`, `monospace` | — | `halign: end`, margins 4/4/top 1, single-line, tooltip "n / total" |
| `Gtk.Label` (value cell) | 1 | `numeric`, `dimmed` (dynamic), `monospace` (when `monospace-font`) | — | `xalign 0.0`, margin-start 4, single-line; widget name = column index, read back by the click gesture |

`dimmed` is the dynamic class: applied for `NULL`, a value-less `NUMERIC`, and
every `BLOB`; removed otherwise. Tooltip prefixed `◇ PRIMARY_KEY  ` on a key
column. Both sides re-read before every write against ColumnView cell reuse.

### `src/gtk/widgets/drop_target.rs` → `lib/bobby/widgets/drop_target.rb`

`Gtk.DropTarget` on `Gdk::FileList`, `DragAction::COPY`, `drop` handler hands
the list to `Gio::Application#open` and returns true. Present.

---

## Dialogs

### `src/gtk/dialogs/about.rs` → `lib/bobby/dialogs/about.rb`

`Adw.AboutDialog` ×1. Eight fields: application icon, application name,
developer name, version, website, issue URL, copyright, `License::Gpl30`. All
eight present. Upstream's `from_appdata()` TODO and `add_other_app()` TODO are
unbuilt on both sides.

### `src/gtk/dialogs/file.rs` → `lib/bobby/dialogs/file.rb`

| Widget | × | Notes |
|---|---:|---|
| `Gtk.FileDialog` | 1 | `modal`, `open_multiple` |
| `Gtk.FileFilter` | 2 | "SQLite Databases" (2 MIME types, 4 patterns), "All Files" (`*`) |
| `Gio.ListStore` | 1 | holds the filters |

All patterns and MIME types present and byte-identical.

### `src/gtk/dialogs/preferences.rs` → `lib/bobby/dialogs/preferences.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.PreferencesDialog` | 1 | — |
| `Adw.PreferencesPage` | 1 | title "Preferences", `org.gnome.Settings-system-symbolic` |
| `Adw.PreferencesGroup` | 2 | "Rows &amp;amp; Columns", "Appearance" |
| `Adw.SwitchRow` | 2 | "Row Numbers" (bound to `row-numbers`), "Monospace Font" (bound to `monospace-font`) |
| `Adw.ComboRow` | 2 | "Row Order" (2 choices), "Column Separator" (4 choices, subtitle) |
| `Gtk.StringList` | 2 | the combo models |

Signals: `notify::selected` on each combo. All four preference rows present.
Upstream resolves a combo's position against the schema's `<choices>` through
`SettingsSchemaSource`; the port keeps the same list in
`Settings::CHOICES` (`lib/bobby/settings.rb:42-45`) — same values, read from a
second place.

### `src/gtk/dialogs/shortcuts.rs` → `lib/bobby/dialogs/shortcuts.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | — |
| `Adw.ShortcutsSection` | 2 | "General" (5 items), "Tables" (1 item) |
| `Adw.ShortcutsItem` | 6 | Open File `<Primary>o`, Open Menu `F10`, Reload Window `<Primary>r`, Close Window `<Primary>w`, Quit `<Primary>q`, Copy Row `<Primary>c` |

6/6 present. Upstream's commented-out "Jump To Row" `<Primary>l` is unbuilt on
both sides.

---

## Actions and accelerators — the full census

| Action | Accelerator | Upstream | Port |
|---|---|---|---|
| `app.about` | — | `actions/app_about.rs` | `actions/app_about.rb` |
| `app.open` | `<Primary>o` | `actions/app_open.rs` | `actions/app_open.rb` |
| `app.open-menu` | `F10` | `widgets/menu.rs:33-38` | `widgets/menu.rb:36-40` |
| `app.preferences` | `<Primary>comma` | `actions/app_preferences.rs` | `actions/app_preferences.rb` |
| `app.quit` | `<Primary>q` | `actions/app_quit.rs` | `actions/app_quit.rb` |
| `app.shortcuts` | `<Primary>question` | `actions/app_shortcuts.rs` | `actions/app_shortcuts.rb` |
| `win.close` | `<Primary>w` | `actions/win_close.rs` | `actions/win_close.rb` |
| `win.copy-row` | `<Primary>c` | `actions/win_copy_row.rs` | `actions/win_copy_row.rb` |
| `win.copy-val` | — (target `s`) | `actions/win_copy_val.rs` | `actions/win_copy_val.rb` |
| `win.reload` | `<Primary>r` | `actions/win_reload.rs` | `actions/win_reload.rb` |
| `win.table` | — (stateful, `s`) | `actions/win_switch_table.rs` | `actions/win_switch_table.rb` |

11/11 actions, 9/9 accelerators. `app.reload` appears twice in the upstream
action stream — it is the banner's `action_name`, and **no upstream action
answers it**; the port points the banner at `win.reload` instead.
`win.open-table-menu` appears twice in the upstream stream from a commented-out
line in `switcher.rs:46`, unbuilt on both sides.

## Empty and error states

| State | Upstream | Port |
|---|---|---|
| Empty window | `window_show_empty_state`: `studio.planetpeanut.Bobby-symbolic`, "Browse Databases", "Drag and drop \<b\>SQLite files\</b\> here", open pill | `Window#show_empty_state` — identical strings |
| Unopenable file | `window_show_error_state`: `dialog-error-symbolic`, "Unable to Open File", the error text, open pill | `Window#show_error_state` — identical |
| Not a database | `"File is not a <b>SQLite database</b> or encrypted"` (`database.rs:33`) | `Database::NOT_A_DATABASE` — identical |
| Cannot connect | `"Could not open a database connection"` | `Database::NO_CONNECTION` — identical |
| No tables | `"Table list empty"` | `Window::NO_TABLES` — identical |
| Unknown table | `"Table does not exist"` | `Window::NO_SUCH_TABLE` — identical |
| Root | `"Cannot run as root"`, exit 255 | `Application::ROOT_REFUSAL` — identical |
| No HOME | `"Could not read HOME environment variable"`, exit 255 | `App#home_dir` — identical |
| No local path | `"Selected file has no local path"` | `Application::NO_LOCAL_PATH` — identical |

The empty state's icon `studio.planetpeanut.Bobby-symbolic` is the one the port
has no file for — see `component-parity.md`.
