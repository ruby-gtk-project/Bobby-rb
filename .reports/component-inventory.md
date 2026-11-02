# Upstream component inventory — Bobby → Bobby-rb

| | |
|---|---|
| Upstream | `origin/main` (Rust, gtk4-rs + libadwaita) |
| Port | `ruby` branch, `lib/bobby/**` |
| Inventory taken at | port `28bb3a5`. The unit list below is still the unit list; the gap ids and the parity figures that were current when it was written are not. `PORTING.md` carries the current ones |
| Declarative UI upstream | **none** — `git ls-tree -r --name-only origin/main` lists no `.ui`, no `.blp`, no `.css`, no `.gresource.xml`. Every widget is built in Rust builder chains |
| GSettings schema | `data/studio.planetpeanut.Bobby.gschema.xml` — 4 keys (`row-numbers` b, `row-order` s/2 choices, `column-separator` s/4 choices, `monospace-font` b) |
| `po/` catalogue | **none upstream.** No `po/`, no `LINGUAS`, no `POTFILES`, no `gettext`/`_()` call anywhere in `src/`. Every user-facing string is an inline Rust literal |
| Desktop / AppStream | `data/*.desktop`, `data/*.metainfo.xml`, two icons — all present in the port's `data/` |

Step 1 of `component-identification` (find the declarative UI) returned nothing
on either side, so the unit list below is the skill's fallback: **one unit per
upstream builder source file, plus one unit for the application class.** Counts
were read out of the source; the `action` stream of a text scan is useless here
because upstream's action names live in `SimpleAction::new("…")` calls spread
over ten files and the `win.`/`app.` prefix is supplied by the widget.

---

## Status summary

**Every user-facing component upstream has exists in the port.** 21 of 21
present. The port adds two files with no single upstream counterpart
(`lib/bobby/settings.rb`, `lib/bobby/util.rb`), both of which hold code
upstream inlines or duplicates.

---

## src/gtk/lib.rs — the application: actions, accelerators, settings watches

→ `lib/bobby/application.rb` · **present**

| Component | × | Behaviour |
|---|---:|---|
| `Adw.Application` (port: `Gtk::Application` + `Adwaita.init`) | 1 | `ApplicationFlags::HANDLES_OPEN`; `open`, `activate` |
| GSettings watches | 3 | `row-numbers` → toggle in place; `row-order`, `monospace-font` → reload window |
| app actions registered | 5 | `app.about`, `app.open`, `app.preferences`, `app.quit`, `app.shortcuts` |

`Adwaita::Application` is broken in the Ruby bindings, so the port constructs a
`Gtk::Application` and calls `Adwaita.init` itself — every window and dialog is
still Adwaita's.

## src/gtk/windows/window.rs — one database window, in three states

→ `lib/bobby/window.rb` · **present** (upstream's largest file, 532 lines)

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (port: `Gtk::ApplicationWindow` + hidden titlebar `Gtk::Box`) | 1 | `flat` | hosts `win.*`; `Gtk::DropTarget` controller | 960×640 |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` is state: `Flat` empty/error, `RaisedBorder` content |
| `Adw.HeaderBar` | 1 | — | — | `pack_start` switcher, `pack_end` main menu |
| `Adw.StatusPage` — **empty state** | 1 | — | — | `studio.planetpeanut.Bobby-symbolic`, "Browse Databases", "Drag and drop **SQLite files** here" |
| `Adw.StatusPage` — **error state** | 1 | — | — | `dialog-error-symbolic`, "Unable to Open File", description = the error |
| `Adw.ToastOverlay` | 1 | — | — | content state only; host for both copy toasts |
| `Gtk.Box` (vertical) | 1 | — | — | banner + content |
| `Adw.Banner` | 1 | — | button → `win.reload` | "File has changed" / "Reload", `BannerButtonStyle::Suggested`. **Never revealed on either side** — upstream's `.revealed(true)` is commented out pending a file watch. Upstream's button targets `app.reload`, which no action answers; the port targets `win.reload`, which does |
| window actions installed | 4 | — | `win.close`, `win.copy-row`, `win.copy-val`, `win.reload`, `win.table` | `win.close` at build; the rest once content exists |

Upstream keeps no references, so it re-finds its own widgets by name
(`widget_by_name("header_bar" / "switcher" / "content" / "toolbar_view")`),
stashes the `Database` with `set_data("db", …)`, and marks an empty window by
setting its widget name to `"1"` (`IS_EMPTY_WINDOW`). The port replaces all
three with memoized accessors, an attribute and `#empty?`.

Upstream's `window_change_content` ends in `// TODO: Swap the content here.` —
the table switch is wired but the swap is unfinished upstream. The port
implements it (`#swap_content`).

## src/gtk/widgets/content.rs — the table

→ `lib/bobby/widgets/content.rb` · **present**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | named `content` upstream; `vexpand` |
| `Gtk.ColumnView` | 1 | — | `Gtk.GestureClick` (BUTTON_SECONDARY) → context menu | rubberband off, `single_click_activate`, row + column separators, `ListTabBehavior::Cell` |
| `Gtk.SingleSelection` | 1 | — | — | over `DatabaseCacheModel` |
| `Gtk.ColumnViewColumn` | **repeater** | — | — | 1 + N: reserved index column at 0, then one per table column. Index column fixed-width from a measured Pango digit advance, `visible` from `row-numbers`. Value columns: BLOB 128 non-resizable, TEXT 192, else 128; last column expands; a primary key appends `◇` to the title |
| `Gtk.SignalListItemFactory` | **repeater** | — | `setup`, `bind` | one per column |
| `Gtk.PopoverMenu` — cell context menu | 1 | — | `win.copy-val::<row>:<col>`, `win.copy-row` | `has_arrow(false)`, `pointing_to` the click point. Upstream also has a commented-out "Copy Rows" |
| `Gtk.GestureClick` | 1 (controller) | — | `pressed` | picks the widget under the pointer and reads the column index off its widget name |

`content_force_redraw` (hide then re-show every column) is the documented HACK
for the separator glitch after a visibility change; the port keeps it as
`#force_redraw`.

## src/gtk/widgets/item.rs — the two cell widgets

→ `lib/bobby/widgets/item.rb` · **present**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Label` — index cell | 1 per visible row | `dimmed`, `monospace` | `halign End`, margins 4/4, `margin_top 1`, single-line; tooltip `"<n> / <total>"` on the **parent** cell |
| `Gtk.Label` — value cell | 1 per visible cell | `numeric`, plus `monospace` when the preference is on, plus `dimmed` **dynamically** for `NULL`, `NUMERIC(None)` and `BLOB` | `xalign 0`, `margin_start 4`, single-line; widget name = column index (the context menu's only way to identify a cell); tooltip is the affinity type then the value, prefixed `◇ PRIMARY_KEY` on a key column. `ellipsize` is commented out upstream as too slow |

Both sides re-read before every write, because a `ColumnView` recycles cells
and a no-op `set_text` still queues a resize.

## src/gtk/widgets/switcher.rs — the table picker

→ `lib/bobby/widgets/switcher.rb` · **present**

| Widget | × | Signals / actions | Notes |
|---|---:|---|---|
| `Gtk.MenuButton` | 1 | menu model | named `switcher`, tooltip "Tables", label = current table name. Upstream's `win.open-table-menu` is commented out |
| `Gio.Menu` sections | 2 | — | `"Views – <n>"` and `"Tables – <n>"` |
| menu items | **repeater** | `win.table::<i>` | one per table; `_` doubled to escape GMenu mnemonics |

Upstream builds the switcher once per window and only ever resets its label, so
reopening a file with different tables leaves a stale menu; the port's
`#tables=` rebuilds the model.

## src/gtk/widgets/menu.rs — the hamburger menu

→ `lib/bobby/widgets/menu.rb` · **present**

| Widget | × | Signals / actions | Notes |
|---|---:|---|---|
| `Gtk.MenuButton` | 1 | — | `open-menu-symbolic`, tooltip "Main Menu" |
| `Gtk.PopoverMenu` | 1 | — | from the model; the port lets GTK build it from `menu_model=` |
| menu items | 3 | `app.preferences`, `app.shortcuts`, `app.about` | labels "Preferences", "Keyboard Shortcuts", "About Bobby" |
| `Gio.SimpleAction` `app.open-menu` | 1 | `activate` → `button.activate()` | accel **F10**; exists only so the keyboard can pop the button |

## src/gtk/widgets/button.rs — the open pill

→ `lib/bobby/widgets/button.rb` · **present**

| Widget | × | CSS | Signals / actions |
|---|---:|---|---|
| `Gtk.Button` | 1 | `pill`, `suggested-action` | label "Open...", `halign Center`. Upstream connects `clicked` and walks window → application to activate `open`; the port sets `action_name = 'app.open'` |

Used twice: once on the empty page, once on the error page.

## src/gtk/widgets/drop_target.rs — file drop

→ `lib/bobby/widgets/drop_target.rb` · **present**

| Component | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.DropTarget` (controller) | 1 | `drop` | `FileList` / `DragAction::COPY`; hands the list to `Gio::Application#open` and always returns true, so a non-database file surfaces as the window's error state |

## src/gtk/dialogs/preferences.rs — preferences

→ `lib/bobby/dialogs/preferences.rb` · **present**

| Widget | × | Notes |
|---|---:|---|
| `Adw.PreferencesDialog` | 1 | — |
| `Adw.PreferencesPage` | 1 | "Preferences", `org.gnome.Settings-system-symbolic` |
| `Adw.PreferencesGroup` | 2 | `"Rows &amp;amp; Columns"` (escaped on both sides — Adwaita renders the title as markup) and "Appearance" |
| `Adw.SwitchRow` | 2 | "Row Numbers" → `row-numbers`, "Monospace Font" → `monospace-font`; both bound to GSettings, no handler |
| `Adw.ComboRow` | 2 | "Row Order" (Newest First / Oldest First) → `row-order`; "Column Separator" (Tabs / Spaces / Commas / Markdown), subtitle "Used when copying rows to the clipboard" → `column-separator`. Both resolve a selected position against the schema's `<choices>` in both directions on `notify::selected` |

## src/gtk/dialogs/shortcuts.rs — keyboard shortcuts

→ `lib/bobby/dialogs/shortcuts.rb` · **present**

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | — |
| `Adw.ShortcutsSection` | 2 | "General", "Tables" |
| `Adw.ShortcutsItem` | 6 | General: Open File `<Primary>o`, Open Menu `F10`, Reload Window `<Primary>r`, Close Window `<Primary>w`, Quit `<Primary>q`. Tables: Copy Row `<Primary>c`. Upstream's commented-out "Jump To Row" `<Primary>l` is unimplemented on both sides and listed on neither |

Note the dialog does **not** list `app.preferences` `<Primary>comma` or
`app.shortcuts` `<Primary>question`, both of which are bound. That gap is
upstream's; the port reproduces it.

## src/gtk/dialogs/about.rs — about

→ `lib/bobby/dialogs/about.rb` · **present**

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | icon, name, developer "Hylke Bons", version, website, `issue_url`, "Copyright © 2025–2026 Hylke Bons", `License::Gpl30`. Upstream's `from_appdata()` and `add_other_app()` are both TODOs |

## src/gtk/dialogs/file.rs — open dialog

→ `lib/bobby/dialogs/file.rb` · **present**

| Widget | × | Notes |
|---|---:|---|
| `Gtk.FileDialog` | 1 | modal, `open_multiple` |
| `Gtk.FileFilter` | 2 | "SQLite Databases" — mime `application/x-sqlite3`, `application/vnd-sqlite3`; patterns `*.db *.db3 *.sqlite *.sqlite3`. "All Files" — `*` |

## src/gtk/actions/*.rs — the ten actions

One upstream file each; one `lib/bobby/actions/*.rb` each. **All ten present.**

| Upstream | Port | Action | Accel | Surfaces |
|---|---|---|---|---|
| `app_about.rs` | `actions/app_about.rb` | `app.about` | — | main menu |
| `app_open.rs` | `actions/app_open.rb` | `app.open` | `<Primary>o` | open pill, shortcuts |
| `app_preferences.rs` | `actions/app_preferences.rb` | `app.preferences` | `<Primary>comma` | main menu |
| `app_quit.rs` | `actions/app_quit.rb` | `app.quit` | `<Primary>q` | shortcuts |
| `app_shortcuts.rs` | `actions/app_shortcuts.rb` | `app.shortcuts` | `<Primary>question` | main menu |
| `win_close.rs` | `actions/win_close.rb` | `win.close` | `<Primary>w` | shortcuts |
| `win_copy_row.rs` | `actions/win_copy_row.rb` | `win.copy-row` | `<Primary>c` | context menu; `Adw.Toast` "Row N copied to clipboard", timeout 2, after `dismiss_all` |
| `win_copy_val.rs` | `actions/win_copy_val.rb` | `win.copy-val` (string target `row:col`) | — | context menu; `Adw.Toast` with the value in `<span font_features='tnum=1'>…</span>`, **only when under 96 chars** |
| `win_reload.rs` | `actions/win_reload.rb` | `win.reload` | `<Primary>r` | banner, shortcuts; no-op on an empty window |
| `win_switch_table.rs` | `actions/win_switch_table.rb` | `win.table` (stateful, string state = table index) | — | switcher menu |

`app.open-menu` / F10 is an eleventh action, installed by `widgets/menu.rs`
rather than by a file of its own; the port installs it in `widgets/menu.rb` the
same way.

## Non-widget upstream units, for completeness

| Upstream | Port | Kind | Present |
|---|---|---|---|
| `src/main.rs` + `src/app.rs` | `lib/bobby/app.rb`, `lib/bobby/application.rb#start` | entry point, app metadata, root refusal | yes |
| `src/cli.rs` | `lib/bobby/cli.rb` | `--help --version --deps --env` | yes |
| `src/log.rs` | `lib/bobby/log.rb` | logging | yes |
| `src/gtk/util.rs` | `lib/bobby/util.rb` | clipboard; `widget_by_name` / `find_column_view` are unneeded in the port | yes |
| `src/bobby/sqlite/{affinity,cache,column,database,row,table}.rs` | `lib/bobby/sqlite/*.rb` (same six names) | model | yes |
| (inline `Settings::new("studio.planetpeanut.Bobby")` in 6 upstream files) | `lib/bobby/settings.rb` | **port-only**: the GSettings access upstream repeats inline, incl. the `<choices>` lookup `preferences.rs` does by hand | yes |

---

## Blockers and carried-over defects

None block further work. Four things are worth recording because they look like
port gaps and are not:

1. **No translation catalogue to port.** Upstream ships no `po/`, no gettext
   calls, no `POTFILES`. Every string is an inline literal on both sides, so
   `translation-parity` has nothing to compare.
2. **No stylesheet to port.** No `.css` on either side; every CSS class in the
   table above comes from the Adwaita stylesheet (`flat`, `pill`,
   `suggested-action`, `dimmed`, `monospace`, `numeric`).
3. **The reload banner is dead on both sides.** Upstream never reveals it
   (the file watch is a TODO) and targets a non-existent `app.reload`; the port
   builds the same banner, also unrevealed, but points it at `win.reload`.
4. **Upstream's table-content swap is unfinished** (`window_change_content`
   returns the new `ScrolledWindow` with a TODO instead of inserting it). The
   port implements the swap, so switching tables works there and not upstream.
