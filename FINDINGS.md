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
- I did not write an install step for the data files, so copying `data/studio.planetpeanut.Bobby.desktop` and the two icons into the repository is as far as it goes: nothing puts them in `share/applications` or `share/icons/hicolor`, so Bobby still does not appear in the app grid, a `.db` file still has no **Open With → Bobby**, and `Window::EMPTY_ICON` and `AboutDialog#application_icon` still have no icon-theme entry to resolve. I am an idiot. Upstream: `data/meson.build` and `data/icons/meson.build` install them; the Flatpak manifest is what runs meson. Port: the gemspec globs `data/**/*` into `spec.files`, which ships the files inside the gem and installs them nowhere.

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
