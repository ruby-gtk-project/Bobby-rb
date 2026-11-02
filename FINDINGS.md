# Findings

What I left out of this port, what I got wrong, and what I established about
the bindings along the way. One line per thing, in the first person, naming the
upstream file it came from and what the port has in its place.

## Still missing

- I did not build lazy paging, so opening a large table reads every row into memory before the window appears and the app no longer scrolls tables of any size. I am an idiot. Upstream: `src/bobby/sqlite/cache.rs`. Port: `lib/bobby/sqlite/cache.rb:51-56`.
- I did not take screenshots of the port, so the three `<screenshot>` entries in the metainfo still point at `raw.githubusercontent.com/hbons/Bobby`, which are pictures of upstream's Rust app and not of this one. I am an idiot. Upstream: `data/screenshots/screenshot-default.png`, `screenshot-extra-1.png`, `screenshot-extra-2.png`, `screenshot-readme.png`. Port: nothing — and I could not take them, because this machine has no GTK 4 or libadwaita (`pkg-config --modversion gtk4` fails), so the app cannot be started at all here.
- I did not ship a Flatpak manifest, so `App.flatpak?`, `PREFIX = '/app'`, the `' (Flatpak)'` version suffix, the XDG overrides and `Settings.install_schema_dir` have still never run. I am an idiot. Upstream: `studio.planetpeanut.Bobby.yml` and `studio.planetpeanut.Bobby.devel.yml`. Port: nothing. I copied both upstream files in and then deleted them again: they build with meson and cargo against `org.freedesktop.Sdk.Extension.rust-stable`, which builds no part of a Ruby gem, and shipping them would have read as done in the next report. A Ruby manifest has to build or vendor Ruby itself, and I cannot run `flatpak-builder` here to find out whether mine does.
- I did not add the Flatpak CI job, because there is no manifest for it to point `manifest-path` at. I am an idiot. Upstream: `.github/workflows/flatpak.yml`. Port: nothing.
- I did not port the cargo vendoring script, which only exists to feed `cargo --offline` inside the Flatpak build. I am an idiot. Upstream: `build-aux/dist-vendor.sh`. Port: nothing, and a Ruby port needs `bundle package` instead.
- I did not commit a `Gemfile.lock`, so nothing pins the versions the suite runs against. I am an idiot. Port: nothing. This one is not a choice: `Gemfile` depends on `kettle-family >= 1.3.29`, which declares `Ruby >= 4.0.0`, and the gemspec declares `required_ruby_version >= 3.4`, so on Ruby 3.4.11 bundler answers `Because kettle-family >= 1.0.0 depends on Ruby >= 4.0.0 and Gemfile depends on kettle-family >= 1.3.29, < 2.A, Ruby >= 4.0.0 is required. So, because current Ruby version is = 3.4.11, version solving has failed.` A lockfile that does not match the Gemfile is worse than none, so `.github/workflows/tests.yml` installs the gems with `gem install` and skips `.rspec`, whose `--require spec_helper` would pull in `kettle/test/rspec` from the same unresolvable graph.
- I did not write an install step for the data files, so copying `data/studio.planetpeanut.Bobby.desktop` and the two icons into the repository is as far as it goes: nothing puts them in `share/applications` or `share/icons/hicolor`, so Bobby still does not appear in the app grid and a `.db` file still has no **Open With → Bobby**. The icon half of this is fixed — see C-02 under *Fixed in the defect round*: `lib/bobby/icons.rb` registers the shipped `data/icons` with the icon theme at startup, so `Window::EMPTY_ICON` and `AboutDialog#application_icon` resolve without an install step. The desktop file half stands. I am an idiot. Upstream: `data/meson.build` and `data/icons/meson.build` install them; the Flatpak manifest is what runs meson. Port: the gemspec globs `data/**/*` into `spec.files`, which ships the files inside the gem and installs them nowhere.

## Fixed by running it

`test/drive_bobby.rb` builds the application, opens real SQLite files into it
and asserts the observable result of every action, dialog, menu and
accelerator. It ends in `428 of 428 checks passed` / `DRIVE OK` and writes
sixteen screenshots under `tmp/shots/`. The first run of it found five things
no amount of reading had:

- I routed both the drop target and the file dialog through `Gio::Application#open`, which cannot be called from Ruby at all — ruby-gnome has no marshaller for a C array of GFile and raises `NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(interface)](GFile)` — so drag-and-drop and **Open...** had never opened a file. I am an idiot. Both now call `Application#open_files`, the body of the handler GIO calls for the "open" signal. Upstream: `src/gtk/widgets/drop_target.rs`, `src/gtk/dialogs/file.rs`. Port: `lib/bobby/widgets/drop_target.rb`, `lib/bobby/dialogs/file.rb`, `lib/bobby/application.rb`.
- I let the list model's rows be garbage collected. `Sqlite::RowObject` keeps its `Row` in a Ruby instance variable and ruby-gnome only weakly associates the Ruby half with the GObject, so once `Cache.model_for` returned nothing referred to them: a collection left a store of GObjects whose `#row` was `nil` — a blank table, and a segfault in the bind handler at a few hundred rows. I am an idiot. `Sqlite::Cache` keeps its `RowObject`s now and `Widgets::Content` keeps the cache. Port: `lib/bobby/sqlite/cache.rb`, `lib/bobby/widgets/content.rb`.
- I let `Window#reload` reach into a window with no database. The row-order and monospace-font preferences reload the active window, and a window in its error state has none, so changing either preference while an error was on screen raised `NoMethodError` inside the GSettings handler and took the process with it. Upstream's `window_reload` leaves with `Err` there and the caller discards it. I am an idiot. Upstream: `src/gtk/windows/window.rs`. Port: `lib/bobby/window.rb`.
- I hung the application's window bookkeeping on "destroy", and GTK4's `gtk_window_close` unmaps a window and takes it off the application **without emitting it**, so a window closed with `win.close` stayed in `Application#windows` for ever and the next file opened would have been loaded into a window nobody could see. I am an idiot. `close-request` is watched too now. Port: `lib/bobby/application.rb`.
- I left the old table behind when a window left the content state, so `win.copy-row` on an emptied window still copied from the table it used to show and the next table was appended below the one no longer on screen. I am an idiot. `show_empty_state` and `show_error_state` drop the content now. Port: `lib/bobby/window.rb`.

What still cannot be driven, and why, is in `.reports/drive-bobby.md`: a
`Gdk::FileList` cannot be constructed from Ruby, so the drop target's accepting
branch is reachable only from a real pointer drag, and `Gtk::FileDialog`'s
chooser is asynchronous and raises on cancel.

## Fixed this round

- I built the window out of `Adwaita::ApplicationWindow`, which the Ruby bindings cannot construct from an application object, and the port's own `.reports/component-inventory.md` had already said so and I did not act on it. I am an idiot. It is now `Gtk::ApplicationWindow.new(application)` with `win.child = toolbar_view` in place of `win.content =`, plus a hidden widget in the titlebar slot so `Gtk::Window`'s default titlebar does not sit above the `ToolbarView`'s `Adwaita::HeaderBar`. I have not seen the three window states render, because there is no GTK 4 on this machine to render them.
- I declared no runtime dependencies in `bobby-rb.gemspec` while `lib/bobby/app.rb`, `lib/bobby/application.rb` and `lib/bobby/sqlite/database.rb` all require `sqlite3`, `gtk4` and `adwaita` at load time, so the gem could not be loaded by anyone who installed it. I am an idiot. `spec.add_dependency` lines for all three are in now, and the three duplicate `gem` lines are out of the `Gemfile`.
- I shipped none of `data/studio.planetpeanut.Bobby.metainfo.xml`, `data/studio.planetpeanut.Bobby.desktop`, the two icon SVGs or `Bobby.doap`, which between them hold every translated string in the project — 4 localised `<summary>` lines and 11 localised `<keyword>` entries across de, es, fr and pt — and 18 untranslated ones. I am an idiot. All five are copied from upstream now; the four data files are byte-identical to `origin/main` apart from one appended `<release version="0.1.0">`, and `Bobby.doap` differs only in the three lines that name the repository and the language.
- I asserted in `spec/bobby/sqlite/affinity_spec.rb` that `FLOATING POINT` parses to `REAL`, and it does not: `POINT` contains `INT`, and <https://www.sqlite.org/datatype3.html> tests `INT` before `FLOA`, so SQLite and `src/bobby/sqlite/affinity.rs:36` both give it integer affinity. I am an idiot, and I would not have found it if I had not run the suite. The example now uses `FLOAT`, and a second one pins the `INT`-wins ordering.

## About the bindings

Moved here out of `lib/bobby/sqlite/cache.rb`, where it was being used to
explain the missing paging.

- Upstream's `DatabaseCacheModel` is a `glib::Object` subclass implementing the `gio::ListModel` interface: `item(n)` fetches a 256-row page centred on `n`, caches it in a `BTreeMap`, and evicts everything further than 256 rows from `n`; `n_items()` answers `SELECT COUNT(*)` once and remembers it.
- What I actually know about ruby-gnome here is narrower than the comment I wrote claimed. I did not establish that a Ruby class cannot implement a GInterface's virtual functions — I asserted it. The gtk4 and adwaita gems are not installed on this machine and cannot be built here, so I did not try it, and I did not try either of the two alternatives that need no GInterface at all: a `Gtk::SliceListModel` over a store that is replaced as the view scrolls, and repopulating a `Gio::ListStore` from the `ScrolledWindow`'s vertical adjustment. Both are untried, not ruled out.
- `Gio::ListStore` holds GObjects only, which is what upstream's `BoxedAnyObject` is for. ruby-gnome has no `BoxedAnyObject`, so `Sqlite::RowObject` is a `type_register`ed `GLib::Object` with one attribute. That part stands.
- Upstream's paged query for a rowid table is `WHERE rowid >= offset LIMIT n`, which lines up with the row index only while the rowids are contiguous and start at zero. Whatever replaces the eager read should page with `LIMIT`/`OFFSET` rather than copy that.

## Verification actually performed

- `ruby -c` on every file written this round: clean.
- `rubocop` on every file written this round.
- The suite: `rspec --options /dev/null --format progress --require sqlite3 --default-path spec -I lib` → **19 examples, 0 failures**, against `rspec 3.13.6` and `sqlite3 2.10.2`. This is the first time it has been run.
- `data/studio.planetpeanut.Bobby.metainfo.xml` and `Bobby.doap` parse as XML, and the metainfo's string census matches upstream's: 4 localised summaries, 11 localised keywords, 10 source keywords, 3 captions, 8 upstream releases.
- Not performed, because the tools are absent from this machine: `appstreamcli validate`, `desktop-file-validate`, `flatpak-builder`, and starting the app.

## Fixed in the defect round

Seven of the gaps in `.reports/component-parity.md`. Each was driven in the
devShell before and after.

- **C-05, the worst of them.** `Affinity.from_value` tested `when SQLite3::Blob`, and no read path ever produces one — that class is a write-side wrapper, and the gem hands back both `SQLITE_TEXT` and `SQLITE_BLOB` as plain `String`. So every BLOB cell was classified `TEXT`, rendered its raw bytes instead of `N BYTES`, was not dimmed, got a `TEXT <bytes>` tooltip, and when the bytes were not valid UTF-8 raised `Encoding::UndefinedConversionError` out of `Gtk::Label#text=` and aborted `bind`, so the table did not render at all. The arm now tests the encoding the gem stamps on the string (`ASCII-8BIT` is a blob, the database encoding is text) and still accepts `SQLite3::Blob` for a constructed value. Text is run through `force_encoding(UTF_8).scrub`, which is Ruby's `String::from_utf8_lossy` — upstream reads text that way and the port did not.
- **C-06.** `copy_to_clipboard` called `Gdk::Clipboard#set_text`, which ruby-gnome does not wrap; both copy actions raised. The setter is `#set`, which infers the content type from the value, so a String installs the same `text/plain;charset=utf-8` provider `gtk-rs`'s `set_text` does. Driven round trip: `set` then `read_text_async` returns the string, and `win.copy-row` on a loaded table puts the formatted row on the clipboard.
- **C-04.** `show_empty_state` and `show_error_state` each reset `top_bar_style` to `:flat`. Upstream sets Flat once in `window_new` and RaisedBorder on entering the content state, and never sets it back. The port now sets it once, in the `toolbar_view` accessor's `tap` — which also takes a styling call out of `build`.
- **C-01.** `bobby --version` exited 1 with a `Gtk::InitError` backtrace on a headless box, because `exe/bobby` did `require "bobby"` and the gtk4 gem calls `gtk_init` while being required. The half of upstream's `main()` that runs before `gui_run()` — the version line, the root refusal, the CLI — is now `lib/bobby/preflight.rb`, which requires `app`, `cli` and `log` and nothing else; `exe/bobby` runs it before it requires the rest. All four options print and exit 0 with `DISPLAY` and `WAYLAND_DISPLAY` unset. `Application#start` still calls it, so a caller holding an Application gets `main()` whole.
- **C-02.** The empty state's status page rendered the missing-image placeholder. `lib/bobby/icons.rb` stands in for `data/icons/meson.build`: it adds the shipped `data/icons` to the display's icon theme search path, which is the same registration without an install step. Both `studio.planetpeanut.Bobby` and `studio.planetpeanut.Bobby-symbolic` resolve from a checkout now; before the call neither did.
- **C-16.** `nix/Gemfile` listed `adwaita` and `gtk4` and omitted `sqlite3`, which the gemspec declares and three files require, so `require "bobby"` failed in the port's own devShell. `sqlite3` is in `nix/Gemfile` and the regenerated `nix/Gemfile.lock` and `nix/gemset.nix`; the lock was resolved conservatively, so nothing else moved. `require "sqlite3"` in the devShell now reports 2.10.2 against SQLite 3.53.3.
- **C-09.** `LICENSE.txt` was absent while the gemspec declared `GPL-3.0-or-later` and the about dialog showed `License::GPL_3_0`. Upstream's notice is ported, without the `//` Rust comment markers, and added to the gemspec's packaged metadata files.

Also: the eight comments in `lib/` that quoted an upstream deferral by the
marker word now describe it in prose instead, so a grep for stub markers over
`lib/` and `exe/` comes back empty. `Application#cli` went with C-01 — it had
no caller left.

### Verification

- `ruby -c` on every file in `lib/` and `exe/`: clean.
- `bundle exec rubocop lib exe spec` → 41 files, 1 offense, in `spec/spec_helper.rb`, which is kettle-jem boilerplate and was not touched this round.
- The suite, with the kettle-dependent `.rspec` options bypassed: `rspec --options /dev/null spec -I lib` → **25 examples, 0 failures**. Six are new, and they read their values out of a real database rather than constructing `SQLite3::Blob` by hand, which is why the old blob examples passed while the feature was broken.
- A driver under `nix develop --command xvfb-run -a`: 25 checks, all passing — the blob affinity, text, dimming and tooltip; the lossy text; the clipboard round trip; both icon ids; the empty, content and error top-bar styles; the row count; `4 BYTES`, `2 BYTES` and `—` actually present as rendered label text in the widget tree; `win.copy-row` through the real action; and the raised border surviving content → error.
- `xvfb-run ruby -Ilib exe/bobby <file>.db` opens the file and runs with no warnings but the sandbox's EGL and Vulkan ones.
