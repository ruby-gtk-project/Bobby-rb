# Bobby component inventory (upstream `origin/main` vs `ruby`)

Surveyed with the `component-identification` skill: `component-scan.sh` run over
both `origin/main` (checked out to a scratch dir via `git archive`, never
checked out in-tree) and the `ruby` branch's `lib/`, cross-checked by reading
every file. Bobby is a gtk-rs app with no `.ui`/`.blp`/GResource files — all
widgets are built in code — and no `po/` catalogue upstream, so neither applies
here.

**Headline finding: the port already has full file-level parity.** Every
upstream source file that contributes a user-facing component already has a
corresponding `lib/*.rb` file on `ruby`, and a spot-check of three components
(the app/window glue in `src/gtk/lib.rs` → `lib/bobby/application.rb`, the main
window in `src/gtk/windows/window.rs` → `lib/bobby/window.rb`, and the GSettings
schema → `lib/bobby/settings.rb`) found the widget trees, actions and settings
keys all accounted for. No component is missing a file. This step did not
re-verify every signal/CSS-class row by hand (see Notes), so component-parity
verification remains a separate pass.

## Windows

| Upstream | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `src/gtk/windows/window.rs` | `lib/bobby/window.rb` | window (`Adw.ApplicationWindow`, header bar, toolbar view, column view, banner, status pages) | ✅ |
| `src/gtk/windows/prelude.rs` | absorbed into `lib/bobby/window.rb` (no re-export module needed in Ruby) | glue | ✅ |

## Dialogs

| Upstream | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `src/gtk/dialogs/about.rs` | `lib/bobby/dialogs/about.rb` | dialog (`Adw.AboutDialog`) | ✅ |
| `src/gtk/dialogs/file.rs` | `lib/bobby/dialogs/file.rb` | dialog (`Gtk.FileDialog` + filters) | ✅ |
| `src/gtk/dialogs/preferences.rs` | `lib/bobby/dialogs/preferences.rb` | dialog (`Adw.PreferencesDialog`: pages, groups, combo/switch rows) | ✅ |
| `src/gtk/dialogs/shortcuts.rs` | `lib/bobby/dialogs/shortcuts.rb` | dialog (`Adw.ShortcutsDialog`, sections, items — keyboard shortcuts) | ✅ |

## Widgets

| Upstream | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `src/gtk/widgets/button.rs` | `lib/bobby/widgets/button.rb` | widget (pill/suggested-action button — empty-state "Open File") | ✅ |
| `src/gtk/widgets/content.rs` | `lib/bobby/widgets/content.rb` | widget (`Gtk.ColumnView`, factories, popover menu, click gesture) | ✅ |
| `src/gtk/widgets/drop_target.rs` | `lib/bobby/widgets/drop_target.rb` | widget/controller (`Gtk.DropTarget` on the window) | ✅ |
| `src/gtk/widgets/item.rs` | `lib/bobby/widgets/item.rb` | widget (column-view cell label, dimmed/monospace/numeric CSS) | ✅ |
| `src/gtk/widgets/menu.rs` | `lib/bobby/widgets/menu.rb` | widget (primary `Gtk.MenuButton` / app menu) | ✅ |
| `src/gtk/widgets/switcher.rs` | `lib/bobby/widgets/switcher.rb` | widget (table-switcher `Gtk.MenuButton`) | ✅ |

## Actions (app/window actions, incl. keyboard-shortcut targets)

| Upstream | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `src/gtk/actions/prelude.rs` | absorbed (each action required individually) | glue | ✅ |
| `src/gtk/actions/app_about.rs` | `lib/bobby/actions/app_about.rb` | action (`app.about`) | ✅ |
| `src/gtk/actions/app_open.rs` | `lib/bobby/actions/app_open.rb` | action (`app.open`) | ✅ |
| `src/gtk/actions/app_preferences.rs` | `lib/bobby/actions/app_preferences.rb` | action (`app.preferences`) | ✅ |
| `src/gtk/actions/app_quit.rs` | `lib/bobby/actions/app_quit.rb` | action (`app.quit`) | ✅ |
| `src/gtk/actions/app_shortcuts.rs` | `lib/bobby/actions/app_shortcuts.rb` | action (`app.shortcuts`) | ✅ |
| `src/gtk/actions/win_close.rs` | `lib/bobby/actions/win_close.rb` | action (`win.close`) | ✅ |
| `src/gtk/actions/win_copy_row.rs` | `lib/bobby/actions/win_copy_row.rb` | action (`win.copy-row`, toast) | ✅ |
| `src/gtk/actions/win_copy_val.rs` | `lib/bobby/actions/win_copy_val.rb` | action (copy cell value, toast) | ✅ |
| `src/gtk/actions/win_reload.rs` | `lib/bobby/actions/win_reload.rb` | action (`win.reload` / `app.reload`) | ✅ |
| `src/gtk/actions/win_switch_table.rs` | `lib/bobby/actions/win_switch_table.rb` | action (table-switcher state action) | ✅ |

## App glue, CLI, settings, data

| Upstream | → lib/*.rb | Kind | Exists |
|---|---|---|---|
| `src/gtk/mod.rs` | absorbed into `lib/bobby.rb` requires | module index | ✅ |
| `src/gtk/lib.rs` | `lib/bobby/application.rb` | application (GApplication, activate/open, 3 settings watches, 5 app actions) | ✅ |
| `src/gtk/util.rs` | `lib/bobby/util.rb` | helper | ✅ |
| `src/gui.rs` | absorbed into `lib/bobby/application.rb` (`Gui` trait → `#run_gui`) | interface | ✅ |
| `src/app.rs` | `lib/bobby/app.rb` | app info / XDG paths | ✅ |
| `src/cli.rs` | `lib/bobby/cli.rb` | CLI arg parsing (`--help`/`--version`/`--deps`/`--env`) | ✅ |
| `src/main.rs` | `exe/bobby` + `lib/bobby/preflight.rb` | entry point / preflight | ✅ |
| `src/log.rs` | `lib/bobby/log.rb` | logging | ✅ |
| `src/bobby/mod.rs`, `src/bobby/prelude.rs` | absorbed into `lib/bobby.rb`, `lib/bobby/rb.rb` | module index | ✅ |
| `src/bobby/sqlite/affinity.rs` | `lib/bobby/sqlite/affinity.rb` | data layer | ✅ |
| `src/bobby/sqlite/cache.rs` | `lib/bobby/sqlite/cache.rb` | data layer | ✅ |
| `src/bobby/sqlite/column.rs` | `lib/bobby/sqlite/column.rb` | data layer | ✅ |
| `src/bobby/sqlite/database.rs` | `lib/bobby/sqlite/database.rb` | data layer | ✅ |
| `src/bobby/sqlite/row.rs` | `lib/bobby/sqlite/row.rb` | data layer | ✅ |
| `src/bobby/sqlite/table.rs` | `lib/bobby/sqlite/table.rb` | data layer | ✅ |
| `data/studio.planetpeanut.Bobby.gschema.xml` (4 keys: `row-numbers`, `row-order`, `column-separator`, `monospace-font`) | `data/studio.planetpeanut.Bobby.gschema.xml` (copied) + `lib/bobby/settings.rb` (wrapper, all 4 keys present) | GSettings schema | ✅ |
| `data/studio.planetpeanut.Bobby.desktop` | `data/studio.planetpeanut.Bobby.desktop` | desktop entry | ✅ |
| `data/studio.planetpeanut.Bobby.metainfo.xml` | `data/studio.planetpeanut.Bobby.metainfo.xml` | AppStream metadata | ✅ |
| `data/icons/hicolor/scalable/apps/studio.planetpeanut.Bobby.svg` | same path | icon | ✅ |
| `data/icons/hicolor/symbolic/apps/studio.planetpeanut.Bobby-symbolic.svg` | same path | icon | ✅ |
| `po/` | — | translation catalogue | N/A — upstream has no `po/` directory |
| `.ui` / `.blp` files | — | declarative UI | N/A — upstream builds all widgets in Rust code; no declarative UI files exist on either side |
| GResource manifest | — | resource bundle | N/A — upstream's `meson.build` registers no `.gresource` |

## Notes / residual risk

- This is a **file-existence inventory**, as the task asked for. It is not a
  full `component-parity` check: counts for `lib/bobby/widgets/switcher.rb`
  and `lib/bobby/actions/win_switch_table.rb` looked thinner in the raw scan
  than their upstream counterparts, and `lib/bobby/widgets/menu.rb` /
  `widgets/button.rb` showed an `app.open` action where upstream's
  `widgets/menu.rs` showed `app.open-menu` — these may be real naming
  differences or scan artifacts (upstream builds several widgets via
  unqualified `Foo::builder()` calls that the regex-based scanner
  under-matches; this was confirmed directly for `window.rs`, where 11 raw
  matches undercount a ~30-widget tree the Ruby side reproduces correctly).
  Recommend running `component-parity` next if closer verification is wanted.
- `symbols.tsv` for the GIR-based classifier already existed in
  `.claude/skills/component-identification/scripts/` on this machine and was
  reused as-is.
