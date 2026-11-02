# Component identification — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe` (gtk-rs, Rust) |
| Port | `ruby` @ `28bb3a5` |
| Declarative UI upstream | **none** — no `.blp`, no `.ui`, no `.css`, no GResource. Every widget is built in Rust code |
| Declarative UI in the port | none, by design (memoized accessors) |
| Scan rows | upstream 70, port 75 |

`component-identification` Step 1 was run on both trees and returned nothing on
either:

```
git ls-tree -r --name-only origin/main | grep -ciE 'assets|\.blp|\.css|\.ui$'   → 0
find Bobby-rb \( -name '*.ui' -o -name '*.blp' -o -name '*.css' \)              → none
grep -rn 'CssProvider\|load(data:' lib/                                         → none
```

So there is no template root to take the unit list from, and no stylesheet on
either side. The unit list below is one top-level builder per upstream source
file, plus one unit for the application, exactly as the skill's fallback
prescribes. Every widget count here was read out of the source; the scan was
used only to say where to look, because gtk-rs builder chains
(`Label::builder()…build()`) and actions whose names are constants are both
systematically under-reported — the `action` stream found 3 of the port's 10
actions.

All counts and all behaviour marked "driven" below were confirmed by running
the port: `nix develop`, GTK 4.22.4, `gtk4-broadwayd`, 86 checks over 22 steps.
Screenshots are in the component-parity report.

---

## Unit: application — `src/gtk/lib.rs`, `src/main.rs`, `src/app.rs`, `src/cli.rs`, `src/log.rs`, `src/gui.rs`

Not a widget. Holds the application object, the five app actions, their
accelerators, the three GSettings watches and the CLI.

| Item | × | Notes |
|---|---:|---|
| `Adw.Application` | 1 | `application_id = studio.planetpeanut.Bobby`, flags `HANDLES_OPEN` |
| signal `open` | 1 | raises an already-open window by path, else `window_handle_open` |
| signal `activate` | 1 | raises the active window, else builds a new one |
| action `app.about` | 1 | no accelerator |
| action `app.open` | 1 | `<Primary>o` |
| action `app.preferences` | 1 | `<Primary>comma` |
| action `app.quit` | 1 | `<Primary>q` |
| action `app.shortcuts` | 1 | `<Primary>question` |
| settings watch `row-numbers` | 1 | → `window_toggle_row_numbers` |
| settings watch `row-order` | 1 | → `window_toggle_row_order` (activates `win.reload`) |
| settings watch `monospace-font` | 1 | → `window_toggle_monospace_font` (activates `win.reload`) |

CLI options, all printing and exiting 0: `--help`, `--version`, `--deps`,
`--env`. Only `args[1]` is examined; anything else falls through to the GUI.
Startup refuses to run as root with `Cannot run as root` and exit 255.

Port: `lib/bobby/application.rb`, `app.rb`, `cli.rb`, `log.rb`, `util.rb`.
`src/gui.rs` is a one-method trait with no Ruby counterpart needed.

## Unit: window — `src/gtk/windows/window.rs` → `lib/bobby/window.rb`

One database, or one window waiting for one. Three states, swapped into a
`ToolbarView`'s content.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `flat` | action `win.close` installed here | 960×640 |
| `Adw.ToolbarView` | 1 | — | — | `top_bar_style` is part of the state: `Flat` empty/error, `RaisedBorder` content |
| `Adw.HeaderBar` | 1 | — | — | named `header_bar`; switcher packed start, main menu packed end |
| `Adw.StatusPage` (empty) | 1 | — | — | icon `studio.planetpeanut.Bobby-symbolic`, title `Browse Databases`, description `Drag and drop <b>SQLite files</b> here`, child = open pill |
| `Adw.StatusPage` (error) | 1 | — | — | icon `dialog-error-symbolic`, title `Unable to Open File`, description = the error, child = open pill |
| `Adw.Banner` | 1 | — | `action_name = app.reload`, `button_style = Suggested` | title `File has changed`, button `Reload`. **Never revealed** — `.revealed(true)` is commented out upstream |
| `Gtk.Box` (vertical) | 1 | — | — | banner + content |
| `Adw.ToastOverlay` | 1 | — | — | wraps the box |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` | accepts `Gdk.FileList`, hands it to `Application#open` |

Conditional: the error and content states build a `StatusPage` or the
overlay respectively; only one is in the toolbar view at a time.
Repeaters: none.
Actions installed on the window in the content state only: `win.copy-row`,
`win.copy-val`, `win.reload`, `win.table`.

## Unit: content — `src/gtk/widgets/content.rs` → `lib/bobby/widgets/content.rb`

The table itself.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | named `content`, `vexpand` |
| `Gtk.ColumnView` | 1 | — | — | rubberband off, focusable, `has_tooltip`, not reorderable, column + row separators, single-click-activate, `tab_behavior = Cell` |
| `Gtk.ColumnViewColumn` | **repeater: 1 + N** | — | — | one reserved index column plus one per database column |
| `Gtk.SignalListItemFactory` | **repeater: 1 + N** | — | `setup`, `bind` | index factory for column 0, value factory for the rest |
| `Gtk.SingleSelection` (type) | 1 | — | — | over `DatabaseCacheModel` |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` | `BUTTON_SECONDARY` → context menu |
| `Gtk.PopoverMenu` | 1 per right-click | — | — | `has_arrow = false`, pointed at the click |
| `Gio.Menu` (context) | 2 items | — | — | `Copy` → `win.copy-val::<row>:<col>`, `Copy Row` → `win.copy-row` |
| `Gtk.Label` | 1 | `monospace` | — | throwaway, used only to measure a digit's advance width |

Column sizing: index column fixed to `MARGIN + (digits+2)×char_width + MARGIN`
and not resizable, visibility from `row-numbers`; `BLOB` → 128 and not
resizable; `TEXT` → 192; everything else → 128. The last column expands. A
primary-key column's title gets ` ◇` appended.

## Unit: item — `src/gtk/widgets/item.rs` → `lib/bobby/widgets/item.rb`

The two cell widgets a `ColumnView` row is made of.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Label` (index cell) | 1 per visible row | `dimmed`, `monospace` | — | `halign = End`, `has_tooltip`, margins 4/4/top 1, single-line. Text = position+1, tooltip on the **parent** = `n / total` |
| `Gtk.Label` (value cell) | 1 per visible row per column | `numeric`, plus `monospace` when the preference is on, plus `dimmed` **conditionally** | — | `xalign 0`, `has_tooltip`, `margin_start 4`, single-line. Widget name = the column index, which is how the context menu learns which cell was clicked |

`dimmed` is applied at bind time for `NULL`, a value-less `NUMERIC` and any
`BLOB`, and removed otherwise. The tooltip is `<TYPE> <value>`, prefixed with
`◇ PRIMARY_KEY  ` on a key column.

## Unit: switcher — `src/gtk/widgets/switcher.rs` → `lib/bobby/widgets/switcher.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | menu model | named `switcher`, tooltip `Tables`, label = the open table |
| `Gio.Menu` | 1 + 2 sections | — | — | section `Views – N`, then section `Tables – N` |
| menu item | **repeater: one per table** | — | `win.table::<index>` | underscores doubled to defeat GMenu mnemonics |

## Unit: main menu — `src/gtk/widgets/menu.rs` → `lib/bobby/widgets/menu.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.MenuButton` | 1 | — | — | icon `open-menu-symbolic`, tooltip `Main Menu` |
| `Gtk.PopoverMenu` | 1 | — | — | from the model |
| `Gio.Menu` | 3 items | — | `app.preferences`, `app.shortcuts`, `app.about` | labels `Preferences`, `Keyboard Shortcuts`, `About Bobby` |
| action `app.open-menu` | 1 | — | `activate` → `button.activate()` | `F10`; exists only so the keyboard can pop the button |

## Unit: open button — `src/gtk/widgets/button.rs` → `lib/bobby/widgets/button.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `application.activate_action("open")` | label `Open...`, `halign = Center`. Built twice per window — once for the empty page, once for the error page |

## Unit: drop target — `src/gtk/widgets/drop_target.rs` → `lib/bobby/widgets/drop_target.rb`

| Item | × | Notes |
|---|---:|---|
| `Gtk.DropTarget` (controller) | 1 | `Gdk.FileList`, `DragAction::COPY`; `drop` hands the files to `Application#open` and always returns true |

## Unit: preferences dialog — `src/gtk/dialogs/preferences.rs` → `lib/bobby/dialogs/preferences.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | title `Preferences`, icon `org.gnome.Settings-system-symbolic` |
| `Adw.PreferencesGroup` | 2 | — | — | `Rows &amp; Columns`, `Appearance` |
| `Adw.SwitchRow` | 2 | — | GSettings binding | `Row Numbers` → `row-numbers`, `Monospace Font` → `monospace-font` |
| `Adw.ComboRow` | 2 | — | `notify::selected` | `Row Order` (`Newest First`, `Oldest First`), `Column Separator` (`Tabs`, `Spaces`, `Commas`, `Markdown`) with subtitle `Used when copying rows to the clipboard` |
| `Gtk.StringList` (type) | 2 | — | — | the combo models |

Upstream resolves a combo's index against the schema's `<choices>` through
`SettingsSchemaSource`; the port keeps the same lists as a constant.

## Unit: shortcuts dialog — `src/gtk/dialogs/shortcuts.rs` → `lib/bobby/dialogs/shortcuts.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | |
| `Adw.ShortcutsSection` | 2 | `General`, `Tables` |
| `Adw.ShortcutsItem` | 6 | `Open File` `<Primary>o`, `Open Menu` `F10`, `Reload Window` `<Primary>r`, `Close Window` `<Primary>w`, `Quit` `<Primary>q`; `Copy Row` `<Primary>c` |

A seventh item, `Jump To Row` `<Primary>l`, is commented out at
`src/gtk/dialogs/shortcuts.rs:50`. Neither app implements the shortcut, so
neither dialog lists it.

## Unit: about dialog — `src/gtk/dialogs/about.rs` → `lib/bobby/dialogs/about.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.AboutDialog` | 1 | icon `studio.planetpeanut.Bobby`, name `bobby`, developer `Hylke Bons`, version, website, issue url, copyright `Copyright © 2025–2026  Hylke Bons`, `License::Gpl30` |

## Unit: file dialog — `src/gtk/dialogs/file.rs` → `lib/bobby/dialogs/file.rb`

| Widget | × | Notes |
|---|---:|---|
| `Gtk.FileDialog` | 1 | modal, `open_multiple` |
| `Gtk.FileFilter` | 2 | `SQLite Databases` (mime `application/x-sqlite3`, `application/vnd-sqlite3`; patterns `*.db`, `*.db3`, `*.sqlite`, `*.sqlite3`) and `All Files` (`*`) |

## Unit: actions — `src/gtk/actions/*.rs` → `lib/bobby/actions/*.rb`

Ten actions, none of which the scan's `action` stream found reliably (every
name is a constant or is composed at the call site). Read off the install
sites and then driven:

| Action | Parameter | Accelerator | Behaviour |
|---|---|---|---|
| `app.about` | — | — | about dialog over the active window |
| `app.open` | — | `<Primary>o` | file dialog |
| `app.preferences` | — | `<Primary>comma` | preferences dialog |
| `app.quit` | — | `<Primary>q` | quits |
| `app.shortcuts` | — | `<Primary>question` | shortcuts dialog |
| `app.open-menu` | — | `F10` | activates the hamburger |
| `win.close` | — | `<Primary>w` | closes the window |
| `win.copy-row` | — | `<Primary>c` | copies the selected row with the separator preference, toast `Row N copied to clipboard` (timeout 2) |
| `win.copy-val` | `s` (`"row:col"`) | — | copies one cell, toast `<span font_features='tnum=1'>‘value’  copied to clipboard</span>` (timeout 2) — **suppressed entirely for values of 96 characters or more** |
| `win.table` | `s`, stateful | — | changes table, sets the switcher label, swaps the content |

## Unit: sqlite backend — `src/bobby/sqlite/*.rs` → `lib/bobby/sqlite/*.rb`

No widgets. `DatabaseCacheModel` is the one GObject here: a custom
`gio::ListModel` whose `item(n)` fetches a 256-row page centred on `n`, caches
it in a `BTreeMap` and evicts beyond ±256, and whose `n_items()` answers
`SELECT COUNT(*)` once and remembers it. Rows are carried as
`glib::BoxedAnyObject`.

---

## What the scan over-reported, and why each row was struck

| Row | Verdict |
|---|---|
| `src/gtk/widgets/drop_target.rs widget Adw.ApplicationWindow 1`, and the same in four action files | A function **parameter type**, not a widget built there. Struck |
| `src/gtk/widgets/menu.rs type Adw.Application 1` and seven more | Parameter types. Struck |
| `src/gtk/util.rs widget Gtk.ColumnView 2` | A downcast target inside a tree walk. Struck |
| `src/gtk/windows/window.rs widget Gtk.Widget 3`, `Gtk.ScrolledWindow 3`, `Gtk.ColumnView 1` | All downcast targets of `widget_by_name`, not constructions. Struck — the one real `ScrolledWindow` belongs to `content.rs` |
| `Adw.BannerButtonStyle`, `Gtk.ListItem`, `Gtk.PickFlags`, `Gtk.License` | Enums and flags. Struck |
| `src/gtk/actions/win_switch_table.rs widget Gtk.Box 1` | Parameter type. Struck |
| port `lib/bobby/window.rb widget Gtk.Window 1`, `Gtk.ApplicationWindow 2`, `Adw.ApplicationWindow 1` | One window, counted three times across a comment, a constructor and a doc line. Struck to 1 |
| port `signal index-factory`, `value-factory`, `notify-local`, `changed::` | Method names and a prefix fragment matched as signal names. Struck |
| port `action s`, `action app.open 2` | `GLib::VariantType.new('s')` and a constant plus its doc comment. Struck |

## What the scan under-reported, and how it was recovered

- **Every gtk-rs builder chain.** `Label::builder().css_classes([…]).build()` produced one `Gtk.Label` row for `item.rs` where there are two distinct cell labels with different class sets. Read off the source.
- **Repeaters.** The `ColumnViewColumn`/`SignalListItemFactory` pair and the two cell labels are all built in loops over the table's columns and the model's rows. One scan row each, N on screen.
- **Actions.** 8 of upstream's 10 and 7 of the port's 10 were invisible. Recovered from the install sites and then confirmed by driving `app.has_action?` / `window.has_action?` and `get_accels_for_action` on the running app.
- **Menu models.** `Gio::Menu#append` calls carry the labels and action targets; the scan sees neither. The main menu's 3 items, the context menu's 2 and the switcher's per-table items were all counted by hand.
- **The measuring `Gtk.Label` in `content.rs:128`**, which exists only to ask Pango for a digit's width. Real widget, never parented.
