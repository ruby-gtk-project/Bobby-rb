# Component parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe` |
| Port | `ruby` branch |
| Inventory | `.reports/component-identification.md` |
| Verdict | **NOT AT PARITY — 9 gaps** |

Scope is the whole app: upstream is 2,886 lines of Rust across 41 files and
every one of them is in the ledger.

## Summary

| Axis | Result |
|---|---|
| Count | Every upstream widget has a located counterpart. 0 gaps |
| Style | 6/6 CSS classes, identical counts, all Adwaita stock. 0 gaps |
| Behaviour | 11/11 actions, 9/9 accelerators, 3/3 window states located. **4 gaps** |
| Text | 33 upstream strings in `data/`, 0 in the port. **5 gaps** |

The port's `lib/` tracks upstream's `src/` closely and the widget trees agree
file by file. Everything that is wrong is either outside `lib/` (the whole of
`data/` beyond the gschema) or a behaviour the bindings made expensive and the
port wrote a comment about instead of building.

---

## Ledger

### G1 — The window is built on a widget the bindings cannot construct

**Axis: behaviour. Severity: fatal — if it holds, the app does not open.**

| | |
|---|---|
| Upstream | `src/gtk/windows/window.rs:179` — `ApplicationWindow::builder().application(application)`, then `window.set_content(Some(&toolbar_view))` |
| Port | `lib/bobby/window.rb:160-164` — `Adwaita::ApplicationWindow.new(application)`, then `win.content = toolbar_view` (`:72`) |

`Adwaita::ApplicationWindow` is listed **BROKEN — DO NOT USE** in the `ruby-gtk`
skill (`references/adwaita-quirks.md:180-206`, and again in its summary table at
`:300`): "The Ruby bindings have type interface issues … even composition fails
… `MainWindow(app)` still fails with type errors." The skill's instruction is
`Gtk::ApplicationWindow`, with every other Adwaita widget nested inside it.

The port's own earlier report said so: `.reports/component-inventory.md:60-63`
reads "the current skeleton uses `Adwaita::ApplicationWindow` and needs
correcting". The skeleton was replaced by 378 lines of window and the line was
not corrected.

I could not execute the app to confirm — `gtk4`, `adwaita` and `sqlite3` are
absent from this environment and `bundle install` refuses on a frozen lockfile
with no `Gemfile.lock` present — so this is recorded as unverified-at-runtime
rather than as an observed crash. It is in the ledger because the skill is
unambiguous and because nothing in the port shows it was tried.

**Fix:** `Gtk::ApplicationWindow.new(application)`, and `win.child =` in place
of `win.content =` (`content=` is `Adw.ApplicationWindow`'s API; the
`Adwaita::ToolbarView` nests fine as an ordinary child). Then run it and confirm
all three window states render.

### G2 — Large tables are read whole into memory; the lazy paging is gone

**Axis: behaviour. Severity: high — it is the feature the app advertises.**

| | |
|---|---|
| Upstream | `src/bobby/sqlite/cache.rs` — `DatabaseCacheModel`, a `gio::ListModel` whose `item(n)` fetches a 256-row page centred on `n` (`CACHE_PAGE_SIZE: u32 = 256`), caches it in a `BTreeMap`, and evicts every row further than `GUARD_RADIUS: u32 = 256` from `n`. `n_items()` answers `SELECT COUNT(*)` once and memoises it |
| Port | `lib/bobby/sqlite/cache.rb:51-56` — `Gio::ListStore.new(RowObject)` with `database.rows(table).each { store.append(...) }`: the entire table, eagerly, at open |

`Row.all` is called with no offset and no limit, so the query is
`SELECT * FROM <t> WHERE rowid >= 0 ORDER BY rowid DESC LIMIT 4294967295`
(`lib/bobby/sqlite/row.rb:52-66`) and every row becomes a `RowObject`.

Upstream's `data/studio.planetpeanut.Bobby.metainfo.xml` advertises this
feature in so many words: **"Scroll through tables and views of any size"**.
Opening a million-row table now reads a million rows and allocates a million
GObjects before the window appears.

`lib/bobby/sqlite/cache.rb:34-39` states the reason: "ruby-gnome cannot
implement a GInterface's virtual functions from Ruby, so a custom
`Gio::ListModel` is not available to the port and the lazy paging has nowhere to
live." Per `component-parity`'s own rule — "A binding limitation is a reason a
gap is hard … and leave the row a gap" — that is evidence of cost, not closure.
See `accountability-ensurance.md` A1 for the wording.

**Fix:** implement paging against a model the bindings do expose. A
`Gio::ListStore` whose contents are replaced page-by-page from the scroll
adjustment, or `Gtk::SliceListModel` over a windowed store, both reach the same
visible behaviour without a Ruby-side `GInterface`. Confirm against a table of
≥1,000,000 rows that open time and RSS do not scale with row count.

### G3 — `data/studio.planetpeanut.Bobby.metainfo.xml` is not in the port

**Axis: text. Severity: high.**

Upstream ships it; the port's `data/` holds only `gschemas.compiled` and
`studio.planetpeanut.Bobby.gschema.xml`. The file carries 33 user-visible
strings including every translation the project has (4 localised `<summary>`,
11 localised `<keyword>`), the app description, 3 screenshot captions, 8
releases of release notes, the branding colours, the OARS content rating, 4
categories and the `display_length` requirement. Quantified in
`translation-parity.md`.

Without it the app has no AppStream entry: it cannot appear in GNOME Software,
`AboutDialog::from_appdata()` has nothing to read, and the port's own
`App#appdata_file` (`lib/bobby/app.rb:70`) points at a path nothing writes.

**Fix:** copy the file, then update `<releases>` for the port's version.

### G4 — `data/studio.planetpeanut.Bobby.desktop` is not in the port

**Axis: text and behaviour. Severity: high.**

| | |
|---|---|
| Upstream | `Name=Bobby`, `Exec=bobby %f`, `Icon=studio.planetpeanut.Bobby`, `Categories=Utility;`, `MimeType=application/vnd.sqlite3;application/x-sqlite3;` |
| Port | absent |

`%f` is what makes "Open With → Bobby" on a `.db` file work, and the two MIME
types are what put Bobby in that menu at all. The port's
`App#desktop_file` (`lib/bobby/app.rb:69`) computes a path to a file that does
not exist. Upstream's `HANDLES_OPEN` flag — which the port sets
(`application.rb:59`) — exists to receive exactly these launches.

**Fix:** copy the file and install it from the gem's `data/`.

### G5 — No app icons; the empty state's icon is missing

**Axis: style. Severity: medium.**

| | |
|---|---|
| Upstream | `data/icons/hicolor/scalable/apps/studio.planetpeanut.Bobby.svg` and `data/icons/hicolor/symbolic/apps/studio.planetpeanut.Bobby-symbolic.svg` |
| Port | absent |

Both are referenced by name from ported code:
`Window::EMPTY_ICON = 'studio.planetpeanut.Bobby-symbolic'`
(`lib/bobby/window.rb:52`) is the `Adw.StatusPage` icon on the first screen a
user ever sees, and `AboutDialog#application_icon = App::ID`
(`lib/bobby/dialogs/about.rb:17`) is the about dialog's icon. With no icon
theme entry, GTK falls back to the broken-image glyph on both.

This is the "red Delete that came out grey" case from the skill: the widget is
there and the class is right, and the screen is wrong.

**Fix:** copy both SVGs, install into `hicolor`, and look at the empty state.

### G6 — No Flatpak manifest, though the port is written for Flatpak

**Axis: behaviour. Severity: medium.**

| | |
|---|---|
| Upstream | `studio.planetpeanut.Bobby.yml`, `studio.planetpeanut.Bobby.devel.yml`, `build-aux/dist-vendor.sh`, `.github/workflows/flatpak.yml` |
| Port | absent |

Upstream's only shipping channel is Flatpak, and the port kept all of the code
that depends on it: `App.flatpak?` reading `FLATPAK_ID`, `PREFIX = '/app'`,
`App.version_string` appending " (Flatpak)", the XDG overrides that exist
because Flatpak sets them, and `Settings.install_schema_dir` whose comment says
"an installed copy — Flatpak sets the variable — is left alone"
(`lib/bobby/settings.rb:26-29`). Five code paths are written for a packaging
target the port cannot produce, so none of them has ever run.

Upstream's `.github/workflows/tests.yml` is also the whole test harness — it
runs the suite inside the Flatpak build with `run-tests: true`. The port has no
equivalent; see `test-parity.md`.

**Fix:** port the manifest (the devel one at minimum), add a Flatpak CI job,
and run the port inside it once so those five paths are exercised.

### G7 — The gem declares no runtime dependencies, so the installed app cannot start

**Axis: behaviour. Severity: fatal.**

| | |
|---|---|
| Upstream | `Cargo.toml` declares `gtk4`, `libadwaita`, `gio`, `rusqlite`, `chrono` |
| Port | `bobby-rb.gemspec` — `grep add_dependency` returns nothing. 14 `add_development_dependency` lines, zero runtime |

`gtk4`, `adwaita` and `sqlite3` are required at load time
(`lib/bobby/app.rb:3`, `lib/bobby/application.rb:3-4`,
`lib/bobby/sqlite/database.rb:3`). They are declared in `Gemfile:63,68-69` —
a file whose own banner reads "**Gemfile is for local development ONLY; Gemfile
is NOT loaded in CI**" (`Gemfile:14-16`).

So `gem install bobby-rb && bobby` ends at
`cannot load such file -- sqlite3 (LoadError)`. I reproduced exactly that
failure in this environment.

**Fix:** three `spec.add_dependency` lines in the gemspec.

### G8 — Four screenshots the metainfo points at

**Axis: text. Severity: low.**

Upstream's `data/screenshots/` holds `screenshot-default.png`,
`screenshot-extra-1.png`, `screenshot-extra-2.png`, `screenshot-readme.png`;
the first three are named from `<screenshots>` with the captions "Browse SQLite
files", "Preferences dialog", "Empty page". None is in the port. Blocks G3 from
being usable AppStream.

**Fix:** take three screenshots of the port in those three states — which also
discharges G1 and G5.

### G9 — `Bobby.doap` is not in the port

**Axis: text. Severity: low.**

Upstream ships the GNOME project-description file. Absent from the port. One
copy, with the port's repository substituted.

---

## Located correspondences — present, not gaps

Each one names where the thing lives.

| Upstream | Port | Why it is a correspondence |
|---|---|---|
| `src/gtk/util.rs` `widget_by_name` | — | A tree walk existing only because upstream's free functions keep no references. The port's widgets are memoized accessors (`Window#header_bar`, `#toolbar_view`, `#switcher`, `Content#scroller`, `#column_view`), so every lookup upstream does by name is a method call. All 7 call sites in `window.rs` accounted for |
| `src/gtk/util.rs` `find_column_view` | `Window#content` → `Content#column_view` | Same; `win_copy_row.rs`/`win_copy_val.rs`'s two call sites become `window.content` (`actions/win_copy_row.rb:44`, `win_copy_val.rb:74`) |
| `window.set_data("db", …)` | `Window#database` attr | `window.rs:292`, `win_reload.rs:26-30`, `window_change_content` |
| `IS_EMPTY_WINDOW = "1"` as widget name | `Window#state == :empty`, `#empty?` | `window.rb:84` |
| `window.widget_name() == path` | `Window#key` | `window.rb:98`; `Application#window_for` (`:157`) |
| `glib::BoxedAnyObject` | `Sqlite::RowObject` | `cache.rb:13-22`, a registered `GLib::Object` with one attribute |
| `gio::Settings::new(...)` ×9 | `Settings.instance` | `settings.rb`; upstream leaves a `// TODO` beside each of the nine |
| `SettingsSchemaSource` `<choices>` readback | `Settings::CHOICES` | `settings.rb:42-45` — same four separator values, same two order values |
| `PopoverMenu::from_model` on the menu button | `btn.menu_model = menu` | `widgets/menu.rb:34` — GTK builds the identical popover |
| `button.connect_clicked` → `activate_action("open")` | `btn.action_name = 'app.open'` | `widgets/button.rb:24` — same activation, and GTK disables the button if the action vanishes |
| `Gui` trait (`src/gui.rs`) | `Application#build` / `#run` | A one-method trait; Ruby needs no declaration |
| `meson.build`, `Cargo.toml`, `build-aux/` | `Rakefile`, `bobby-rb.gemspec` | Different build system |
| `src/gtk/actions/prelude.rs`, `src/bobby/prelude.rs`, `src/gtk/mod.rs` | `lib/bobby.rb` | Module re-export plumbing |

## Deliberate divergences, recorded

Both are the port behaving better than upstream, and both are written down
rather than silent — which is what the skill asks for. Neither is a gap.

1. **The banner's action.** Upstream `window.rs:338` sets
   `action_name("app.reload")`; no `app.reload` action exists anywhere in
   upstream, so the banner's button is dead. The port points it at `win.reload`
   (`window.rb:179`), which does exist. Documented at `window.rb:40-43`. The
   banner is never revealed on either side, so neither button is reachable
   today.
2. **The switcher's menu is rebuilt on reopen.** Upstream keeps a window's
   first `table_switcher_new` for the window's life and only sets its label
   (`window.rs:376-397`), so reopening a file whose tables changed leaves a
   stale menu. `Switcher#tables=` (`switcher.rb:52-58`) rebuilds the model.
   Documented at `switcher.rb:24-26`.

Three smaller, undocumented divergences, all harmless and all noted here so
they are not silent: the port resets `toolbar_view.top_bar_style = :flat` in
`show_empty_state` and `show_error_state` (`window.rb:110`, `:120`) where
upstream leaves whatever the previous state set; `Window#close` closes the
SQLite connection before closing the window (`window.rb:80`), which is
upstream's `win_close.rs:21` TODO; and `--env` prints via `pp` rather than
Rust's `{:#?}`.

## Shared limitations — identical on both sides, no gap

Listed so a later reviewer does not read them as port-only.

- The reload banner is built and never revealed; the file-change watch is a TODO
  on both sides (`window.rs:340`). `Database#data_version` — the pragma that
  watch would read — is ported (`database.rb:81-85`) and unused, exactly as
  upstream's is.
- The context menu only opens when the pick lands on the `Gtk.Label` itself, not
  on the cell's internal margin (`content.rs:218` TODO; `content.rb:238`).
- `app.open-menu` is installed once per window against the same app-scoped
  name, so with two windows open F10 reaches only the last one
  (`menu.rs:40`, `menu.rb:30`).
- "Copy Rows" (multi-row copy) is commented out upstream (`content.rs:253-257`)
  and unbuilt in the port.
- "Jump To Row" `<Primary>l` is commented out upstream (`shortcuts.rs:50`) and
  unbuilt in the port.
- `Column#unique` is always false; `PRAGMA table_info` does not report it and
  upstream left the lookup a TODO (`column.rs:36`, `column.rb:63`).
- **Neither side marks a single UI string for translation.** All 60-odd
  user-visible labels are hard-coded English literals in both. See
  `translation-parity.md`.
