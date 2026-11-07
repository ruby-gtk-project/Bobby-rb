# Component parity — Bobby

**Reconfirmed again this round (port @ `d8799c0`, HEAD).** The one commit
since the last reconciliation (`ada9290`), `d8799c0` "Reopen C-12/C-13/C-14
as C-24", touches only `PORTING.md` and corrects it to match what this file
already said: C-12/C-13/C-14 are not closed, they are folded into open gap
C-24 below. `git diff ada9290 HEAD -- lib/ exe/ spec/ test/` is empty.
`nix develop --command xvfb-run -a ruby test/drive_bobby.rb` was re-run live
this round and still ends `474 of 474 checks passed` / `DRIVE OK`, and the
spec suite still ends `36 examples, 0 failures`. Open-gap count is unchanged
at 2 (C-23, C-24); see below.

**Reconciled this round (port @ `314c519`, HEAD).** Everything below this
block is the audit as written at port `9a3ce26` and is now stale in detail:
most of the gaps it lists as open (C-07, C-08, C-10 through C-15, C-17
through C-21) were closed in the commits since, as PORTING.md's own ledger
records. The body is kept because the per-component reading it did is still
correct and still the evidence for *why* each gap was real; only the
open/closed status has moved. Do not read "14 open gaps" below as current.

**Current status, reconfirmed live this round:**

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `ada9290` (HEAD; re-reconciled this round, superseding the `314c519` row below) |
| Open gaps | **2** — C-23 (two of three file-open routes never driven), **C-24, new this round** (Flatpak manifests/CI/vendoring exist but have never been built, run, or even YAML/script-linted by a tool, so "closed" in PORTING.md overstates what happened) |
| Driven | yes, live this round — `nix develop --command xvfb-run -a ruby test/drive_bobby.rb` → **474 of 474 checks passed**, `DRIVE OK`, exit 0, 16 screenshots in `tmp/shots/` |
| C-07 (lazy paging) | **closed** — `Sqlite::Cache` is a `Gio::ListModel` paging 256 rows at a time, per `9a4be48` |
| C-17/C-18/C-19/C-20 (REAL rendering, byte cutoff, dead-toast string, toast assertions) | **closed** — reconfirmed by live grep of `test/drive_bobby.rb`: toast title, `timeout == 2`, `dismiss_all`-driven single-toast-per-repeat, and the 96-byte cutoff are all now asserted (search `d.check` near lines 1213–1378) |
| C-21 (no runnable test command) | **closed** — `nix develop --command xvfb-run -a ruby -e '…require "spec_helper"…'` runs live, **36 examples, 0 failures** |

## This round: C-12/C-13/C-14 are marked closed on the strength of existing, not running

`ada9290` ("Port Flatpak packaging: manifests, CI job, and gem vendoring
script") added `studio.planetpeanut.Bobby.yml`, `.devel.yml`,
`.github/workflows/flatpak.yml`, `build-aux/dist-vendor.sh` and
`Gemfile.flatpak`, and its own commit message says "Closes C-12/C-13/C-14";
PORTING.md's *Closed* table repeats that verdict. What was actually checked,
reproduced live this round:

```
$ which flatpak-builder   → not found (not in the dev shell, confirmed in FINDINGS.md's own "Not performed" list)
$ ruby -ryaml -e 'YAML.load_file("studio.planetpeanut.Bobby.yml")'        → parses
$ ruby -ryaml -e 'YAML.load_file("studio.planetpeanut.Bobby.devel.yml")'  → parses
$ ruby -ryaml -e 'YAML.load_file(".github/workflows/flatpak.yml")'       → parses
$ bash -n build-aux/dist-vendor.sh                                       → syntax OK
```

That is everything that has ever touched these five files: YAML/shell
*syntax* is valid, and nothing else. `flatpak-builder` has never run against
either manifest; the CI workflow has never executed (it is a file in a repo,
not a GitHub Actions run — there is no Actions run against `ruby` to point
at); `build-aux/dist-vendor.sh` has never been executed, so whether `bundle
package --no-install` against `Gemfile.flatpak` actually produces a
`vendor/cache` that `--share=network`-free `bobby` module could build from is
untested; and none of `App.flatpak?`, `PREFIX = '/app'`, the `' (Flatpak)'`
version suffix, the XDG override path or the non-checkout branch of
`Settings.install_schema_dir` has executed under either flag, because no
Flatpak build of this app has ever been produced. This is exactly the
runtime-gate rule stated for this audit: **a component no check exercises is
unverified, not done.** Writing a manifest is necessary for C-12/13/14 but it
is not sufficient, and "closed" is the wrong word for it — it should read
"manifest ported, unbuilt." **This is gap C-24**: three gaps were marked
closed in PORTING.md on the strength of a file existing, not a build
succeeding, and nothing in PORTING.md, FINDINGS.md or this report said so
until now.

The two remaining real gaps, both correctly still open and not excused
anywhere: the drop target's accepting branch plus the file dialog's cancel
path remain reachable only by a real pointer drag or a crafted async result
that nothing in the suite constructs (C-23); and now C-24 above. None of these
report — each is stated as still missing, with what would close it.

---

## Original audit body (port @ `9a3ce26`) — historical, see reconciliation above

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `9a3ce26f5edc81fdd0614ab6e3523ff09305463d` |
| Units with parity | **9 / 16** |
| Open gaps | **14** (C-03, C-07, C-08, C-10 … C-15, C-17 … C-23) |
| Stylesheet | neither side has one; every class used is a GTK/libadwaita platform class, so the CSS axis collapses to attachment |
| Driven | yes — `nix develop --command xvfb-run -a ruby test/drive_bobby.rb` → **428 of 428 checks passed**, `DRIVE OK`, exit 0, 84 steps, 16 screenshots in `tmp/shots/` |

Seven of the sixteen gaps the previous audit (`28bb3a5`) opened were closed in
`ca5cafa` and `9a3ce26` and are not re-listed: C-01 (headless CLI), C-02 (icon
registration), C-04 (top-bar style), C-05 (blob affinity), C-06 (the
clipboard), C-09 (`LICENSE.txt`), C-16 (`sqlite3` in `nix/Gemfile`). Each was
re-verified closed in this round's drive. Seven **new** gaps were found,
C-17 to C-23.

## How this was checked

The gate was reproduced from a cold shell, not taken on report:

```
$ nix develop --command xvfb-run -a ruby test/drive_bobby.rb
428 of 428 checks passed
DRIVE OK                                   (exit 0)
```

84 steps over the real application: the three window states, all eleven
actions, all four dialogs, both menus, the switcher, the preferences round
trip, the CLI, the log, the clipboard, multi-window handling and the close
path. Reading was then done on every one of the 34 upstream `.rs` files against
its port counterpart, because the drive is where behaviour is confirmed and
reading is where missing behaviour is found. Steps 4 and 5 of the skill were
both performed.

Everything below that says "driven" names a step in `tmp/shots/` or in the
drive output; everything that says "read" was established from the source and
is marked as unverified where no check exercises it.

## Whole-app scan, and why it was not trusted

| Axis | Upstream distinct | Port distinct | Only upstream |
|---|---:|---:|---:|
| Widget types | 10 | 22 | 1 |
| CSS classes | 6 | 6 | 0 |
| Signals | 12 | 14 | 2 |
| Actions | 10 | 3 | 8 |

Every number in that table is an artifact of Rust's `use` imports against
Ruby's fully-qualified constants, and of the port building seven of its ten
actions from a `NAME` constant. The `component-identification` report explains
each row. Nothing in it is a finding.

---

## Unit: application — `src/gtk/lib.rs` + `main.rs` + `app.rs` + `cli.rs` + `log.rs` + `gui.rs` → `lib/bobby/application.rb` + `app.rb` + `cli.rb` + `log.rb` + `preflight.rb` + `icons.rb`

| Item | Up × | Port × | Behaviour | Text | Verdict |
|---|---:|---:|---|:-:|---|
| application object | 1 | 1 | ✓ id, `HANDLES_OPEN` (driven, step 0) | — | correspondence: `Gtk::Application` + `Adwaita.init` for `Adw::Application`, which the bindings cannot build from an application object — `lib/bobby/application.rb:124` |
| signal `open` | 1 | 1 | ✓ driven — raises an open file, reuses an empty window, else makes one (steps 61–71) | — | parity |
| signal `activate` | 1 | 1 | ✓ driven (step 0) | — | parity |
| 5 app actions | 5 | 5 | ✓ driven, all installed (step 3) | — | parity |
| 5 accelerators | 5 | 5 | ✓ driven, all match (step 3) | — | parity |
| 3 settings watches | 3 | 3 | ✓ all three driven (steps 46–53, 73) | — | parity |
| root refusal | 1 | 1 | ✓ driven (step 79) | ✓ `Cannot run as root` | parity |
| CLI `--help/--version/--deps/--env` | 4 | 4 | ✓ driven headless, prints and exits 0 (steps 77–79) | ✓ | parity |
| log levels | 6 | 6 | ✓ driven (step 80) | ✓ | parity |
| icon registration | — | 1 | ✓ both ids resolve (step 6) | — | correspondence for `data/icons/meson.build`; the install step itself is still gap C-11 |

Messages: `Cannot run as root`, `Could not read HOME environment variable`,
`Usage: bobby [file]...`, `Options:`, `    --help, --version, --deps, --env`,
`SQLite %s` — 6 upstream, 6 in the port, byte-identical. ✓

Correspondence, located: `--env` prints Ruby's `pp` of a hash where upstream
prints Rust's `{:#?}` of a struct. Same twelve fields in the same order
(`lib/bobby/app.rb:91-105`, driven step 77). A debug dump's own layout is not a
user-visible string.

Correspondence, located: `App.runs_as_root?` reads `Process.uid` where upstream
shells out to `id -u`. Upstream's `Err(_) => true` arm — assume root if `id`
cannot be run — has no counterpart because `Process.uid` cannot fail.

### Unit verdict: **parity**

## Unit: window — `src/gtk/windows/window.rs` → `lib/bobby/window.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application window | 1 | 1 | ✓ `flat` | ✓ `win.close` (driven, step 67) | — | correspondence: `Gtk::ApplicationWindow` + a hidden titlebar; recorded in `FINDINGS.md` |
| `Adw.ToolbarView` | 1 | 1 | — | ✓ Flat → RaisedBorder, never lowered (driven, steps 21, 74) | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | ✓ switcher start, menu end (driven, step 22) | — | parity |
| `Adw.StatusPage` (empty) | 1 | 1 | — | — | ✓ | parity |
| `Adw.StatusPage` (error) | 1 | 1 | — | — | ✓ | parity |
| `Adw.Banner` | 1 | 1 | — | ✗ target differs | ✓ | **gap C-03** |
| `Gtk.Box` | 1 | 1 | — | ✓ banner stays, table is swapped (driven, steps 34, 41) | — | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | ✓ is the content (driven, step 20) | — | parity |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ formats, action, opener (driven, step 60); **accepting branch not driven** | — | **gap C-23** |
| open button | 2 | 2 | ✓ `pill`, `suggested-action` | ✓ `app.open` | ✓ `Open...` | parity |
| error-state message | 0 | 2 | — | — | ✗ | **gap C-22** |

Messages: 6 upstream (`Bobby`, `Browse Databases`,
`Drag and drop <b>SQLite files</b> here`, `Unable to Open File`,
`File has changed`, `Reload`), 6 in the port, byte-identical
(`lib/bobby/window.rb:48-57`). ✓

Driven: empty → content → reload → error → empty all reached and asserted; the
raised border surviving content → error (step 74), the banner's unrevealed
state (step 51 of the drive's checks), the window title tracking the basename,
the scroll offsets coming back on the idle tick (step 43), and the five-bug
regression set from `9a3ce26`.

**C-03 — the reload banner's button targets a different action.** Upstream
`src/gtk/windows/window.rs:350` sets `action_name = "app.reload"`, and no
`app.reload` action exists anywhere upstream, so upstream's banner button is
inert. The port points it at `win.reload` (`lib/bobby/window.rb:241`), which
works. The port is better and the divergence is real: it is on the behaviour
axis, the port fires an action upstream does not, and after two audits it is
still recorded only in a class comment at `window.rb:42-43` and still absent
from `FINDINGS.md`. Open because it is unrecorded where a reader looks, not
because the behaviour is worse.

**C-22 — the port shows the user an error upstream never shows.** When a
database opens but has no browsable table, upstream's
`window_show_content_state` returns `Err("Table list empty")` or
`Err("Table does not exist")`; `window_handle_open` propagates it and
`connect_open` discards it with `_ =`. So upstream presents **no window at all**
for a tableless file opened from the command line, and leaves an existing
window on whatever it was showing. The port catches the same two strings and
renders them as the error status page's description
(`lib/bobby/window.rb:296`, `:414-420`), which the drive asserts as intended
behaviour at steps 16–19. Both strings are upstream's own bytes, so this is not
a text gap; it is a behaviour gap — one state transition exists in the port and
not upstream — and nothing in the repository records it.

**C-23 — the drop target's accepting branch is unverified.** Driven: the
controller's formats, its drag action, its opener, and a drop of a value that
is not a file list (the refusing branch). Not driven: a drop that actually
opens a database, because `Gdk::FileList.new([...])` raises
`NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(interface)](GFile)`
and a `Gdk::FileList` therefore cannot be constructed from Ruby at all. The
same holds for `Gtk::FileDialog`'s chooser, which is asynchronous and raises on
cancel. Drag-and-drop and **Open...** are two of the three documented ways to
open a file in this app, and neither has been exercised end to end by any
check. The binding gap is recorded in `.reports/drive-bobby.md` and
`FINDINGS.md`; it is why the gap is hard, and the gap stays open.

### Unit verdict: **gap** (C-03, C-22, C-23)

## Unit: content — `src/gtk/widgets/content.rs` → `lib/bobby/widgets/content.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Gtk.ColumnView` | 1 | 1 | — | ✓ all 8 construction properties | — | parity |
| `Gtk.ColumnViewColumn` | 1+N | 1+N | — | ✓ 6 for a 5-column table (driven, step 35) | ✓ `name ◇` | parity |
| `Gtk.SignalListItemFactory` | 1+N | 1+N | — | ✓ `setup`, `bind` | — | parity |
| `Gtk.SingleSelection` | 1 | 1 | — | — | — | parity |
| `Gtk.GestureClick` | 1 | 1 | — | ✓ `pressed`, `BUTTON_SECONDARY` (driven, step 24) | — | parity |
| `Gtk.PopoverMenu` | 1 | 1 | — | ✓ `has_arrow = false`, `pointing_to` (driven, step 25) | — | parity |
| context `Gio.Menu` | 2 items | 2 items | — | ✓ `win.copy-val::r:c`, `win.copy-row` (driven, steps 25–29) | ✓ `Copy`, `Copy Row` | parity |
| measuring `Gtk.Label` | 1 | 1 | ✓ `monospace` | — | — | parity |

Column sizing driven: `id ◇` title ✓, TEXT 192 ✓, BLOB 128 and not resizable ✓,
last column expands ✓, index column follows `row-numbers` and flips when the
key is written ✓ (steps 46–49). `force_redraw` reproduces upstream's own HACK.
Messages: 2 upstream, 2 in the port, byte-identical. ✓

Correspondence, located: the port picks the widget under the pointer and reads
the column index off its name exactly as upstream does, and returns nil for the
index column (`content.rb:255-261`) where upstream uses `checked_sub(1)`.

### Unit verdict: **parity**

## Unit: item — `src/gtk/widgets/item.rs` → `lib/bobby/widgets/item.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| index `Gtk.Label` | 1/row | 1/row | ✓ `dimmed`, `monospace` | — | ✓ `n / total` on the parent (driven, step 23) | parity |
| value `Gtk.Label` | 1/cell | 1/cell | ✓ `numeric`, conditional `monospace`, dynamic `dimmed` (driven, steps 23, 53) | — | ✗ REAL values | **gap C-17** |

Driven: the blob cell renders `4 BYTES` / `2 BYTES`, is dimmed and tooltips
`BLOB DE AD BE EF …`; a NULL renders the em dash and is dimmed; a text value is
undimmed; invalid UTF-8 is scrubbed rather than raising; the primary-key
tooltip carries `◇ PRIMARY_KEY  `. All of C-05 is closed.

**C-17 — every REAL cell whose value is integral, very large or very small
renders differently from upstream.** Rust's `Display for f64` prints the
shortest round-tripping decimal and never uses exponent notation; Ruby's
`Float#to_s` always keeps a fractional part and switches to `e+NN` past
10¹⁶. Measured in the devShell against a real table:

| stored | upstream cell | port cell |
|---|---|---|
| `1.0` | `1` | `1.0` |
| `2.5` | `2.5` | `2.5` |
| `0.1` | `0.1` | `0.1` |
| `1e300` | `1` followed by 300 zeros | `1.0e+300` |

The divergence is in `Affinity#to_s` (`lib/bobby/sqlite/affinity.rb:186-192`,
`value.to_s`) against `src/bobby/sqlite/affinity.rs` `Self::REAL(Some(f)) =>
f.to_string()`, so it reaches the cell text, the tooltip (`REAL 1.0` against
`REAL 1`) **and the clipboard**, because `Row#format_with` maps `to_s` over the
cells. A table of integral floats — a column of prices, counts or ids stored
as REAL, which SQLite's dynamic typing makes ordinary — reads differently in
the two apps and copies differently out of them. Nothing in the repository
records it, no spec example covers a REAL value at all, and no drive check
asserts a REAL cell's rendered text.

### Unit verdict: **gap** (C-17)

## Unit: switcher — `src/gtk/widgets/switcher.rs` → `lib/bobby/widgets/switcher.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.MenuButton` | 1 | 1 | — | ✓ tooltip `Tables` (driven, step 22) | ✓ | parity |
| `Gio.Menu` + 2 sections | 1+2 | 1+2 | — | — | ✓ `Views – N`, `Tables – N` | parity |
| menu item | 1/table | 1/table | — | ✓ `win.table::<index>` (driven, steps 34–39) | ✓ underscore doubling (driven) | parity |

Driven on a fixture with one view and three tables: 2 sections ✓, the counts ✓,
the index addressing the full list ✓, the label following `switch_table` ✓, a
non-index target refused with the state unchanged ✓ (steps 38–39), the menu
rebuilt when a window is reopened on a changed file ✓ (step 65).

Correspondence, located and better: upstream reuses a window's first switcher
for ever and only changes its label, so reopening a file whose tables changed
leaves a stale menu; `Switcher#tables=` rebuilds the model
(`switcher.rb:48-55`). Recorded in the class comment at `switcher.rb:21-23`.

### Unit verdict: **parity**

## Unit: main menu — `src/gtk/widgets/menu.rs` → `lib/bobby/widgets/menu.rb`

| Widget | Up × | Port × | Signals / actions | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Gtk.MenuButton` | 1 | 1 | ✓ icon, tooltip (driven, step 4) | ✓ `Main Menu` | parity |
| `Gio.Menu` | 3 items | 3 items (driven) | ✓ three app actions | ✓ `Preferences`, `Keyboard Shortcuts`, `About Bobby` | parity |
| `app.open-menu` + `F10` | 1 | 1 | ✓ driven, pops the menu (step 5) | — | parity |

Correspondence, located: upstream builds `PopoverMenu::from_model` and hands it
to the button; the port sets `menu_model` and lets GTK build the same popover
(`menu.rb:44`).

### Unit verdict: **parity**

## Unit: open button — `src/gtk/widgets/button.rs` → `lib/bobby/widgets/button.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Button` | 2/window | 2/window | ✓ `pill`, `suggested-action` (driven, step 1) | ✓ | ✓ `Open...` | parity |

Correspondence, located: upstream connects `clicked` and walks window →
application to activate `open`; the port sets `action_name = 'app.open'`
(`button.rb:24`), which routes identically and additionally insensitises the
button if the action goes missing.

### Unit verdict: **parity**

## Unit: drop target — `src/gtk/widgets/drop_target.rs` → `lib/bobby/widgets/drop_target.rb`

Rolled into the window unit above; see **C-23**.

### Unit verdict: **gap** (C-23)

## Unit: preferences dialog — `src/gtk/dialogs/preferences.rs` → `lib/bobby/dialogs/preferences.rb`

| Widget | Up × | Port × | Signals | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Adw.PreferencesDialog` | 1 | 1 | — | — | parity |
| `Adw.PreferencesPage` | 1 | 1 | — | ✓ `Preferences`, icon | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | ✓ `Rows &amp; Columns`, `Appearance` | parity |
| `Adw.SwitchRow` | 2 | 2 | ✓ GSettings `bind` (driven both ways) | ✓ `Row Numbers`, `Monospace Font` | parity |
| `Adw.ComboRow` | 2 | 2 | ✓ `notify::selected` (driven both ways) | ✓ `Row Order`, `Column Separator`, subtitle | parity |
| `Gtk.StringList` | 2 | 2 | — | ✓ 6 choice labels | parity |

Messages: 11 upstream, 11 in the port, byte-identical including the escaped
ampersand (asserted at drive step 45). All four rows driven to their effect,
not just their existence: row-numbers hides and re-shows the index column,
row-order re-reads the table in the other direction, monospace restyles every
value cell, column-separator changes what a copied row looks like including the
markdown wrapping (steps 30–31, 46–53).

Correspondence, located: upstream reads the combo choices out of the schema with
`SettingsSchemaSource` → `schema.key(key).range()`; the port keeps them in
`Settings::CHOICES` (`settings.rb:44-47`). Same values, same order, driven
against the shipped schema at step 7. The port's copy can drift from the schema
where upstream's cannot — worth a test, and the spec suite has none for it.

### Unit verdict: **parity**

## Unit: shortcuts dialog — `src/gtk/dialogs/shortcuts.rs` → `lib/bobby/dialogs/shortcuts.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | parity |
| `Adw.ShortcutsSection` | 2 | 2 | ✓ `General`, `Tables` | parity |
| `Adw.ShortcutsItem` | 6 | 6 | ✓ all 6 labels and accelerators | parity |

Driven (step 56): all six listed **and** each one confirmed really registered
on the application, in upstream's order. The commented-out `Jump To Row` /
`<Primary>l` is absent from both.

### Unit verdict: **parity**

## Unit: about dialog — `src/gtk/dialogs/about.rs` → `lib/bobby/dialogs/about.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.AboutDialog` | 1 | 1 | ✓ | parity |

Driven (steps 57–58): icon, name `bobby`, `Hylke Bons`, version, website,
issue url, `Copyright © 2025–2026  Hylke Bons`, `License::GPL_3_0`. Upstream's
`// TODO: from_appdata() if running in Flatpak?` is unbuilt on both sides.

Correspondence, located: `version` is the gem's `0.1.0` against upstream's
`CARGO_PKG_VERSION` `50.0.2`. The port versions itself.

### Unit verdict: **parity**

## Unit: file dialog — `src/gtk/dialogs/file.rs` → `lib/bobby/dialogs/file.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Gtk.FileDialog` | 1 | 1 | — | parity |
| `Gtk.FileFilter` | 2 | 2 | ✓ `SQLite Databases`, `All Files` | parity |

Filters, mime types and patterns all match and are driven by matching real
`Gio::FileInfo`s against them (step 59). The chooser itself is not driven — see
**C-23**.

Correspondence, located: upstream iterates the returned list model calling
`window_handle_open`; the port hands the list to `Application#open_files`, the
body of the handler GIO calls for `open`, because `Gio::Application#open` cannot
be called from Ruby. Driven through `open_files` at steps 61–71.

### Unit verdict: **gap** (C-23)

## Unit: actions — `src/gtk/actions/*.rs` → `lib/bobby/actions/*.rb`

| Action | Up | Port | Accel | Driven | Verdict |
|---|:-:|:-:|---|---|---|
| `app.about` | ✓ | ✓ | — | opens the dialog ✓ | parity |
| `app.open` | ✓ | ✓ | `<Primary>o` | installed ✓ | parity |
| `app.preferences` | ✓ | ✓ | `<Primary>comma` | opens the dialog ✓ | parity |
| `app.quit` | ✓ | ✓ | `<Primary>q` | wired to quit ✓ | parity |
| `app.shortcuts` | ✓ | ✓ | `<Primary>question` | opens the dialog ✓ | parity |
| `app.open-menu` | ✓ | ✓ | `F10` | pops the menu ✓ | parity |
| `win.close` | ✓ | ✓ | `<Primary>w` | closes, closes the db, leaves siblings ✓ | parity |
| `win.reload` | ✓ | ✓ | `<Primary>r` | keeps the table, the rows and the scroll ✓; no-ops on empty and error ✓ | parity |
| `win.table` | ✓ | ✓ | — | switches, follows state, refuses junk ✓ | parity |
| `win.copy-row` | ✓ | ✓ | `<Primary>c` | clipboard holds the row, separator applied ✓; **toast unverified** | **gap C-20** |
| `win.copy-val` | ✓ | ✓ | — | clipboard holds the cell ✓; refuses an unreadable target ✓; **toast unverified, cutoff wrong, one string missing** | **gaps C-18, C-19, C-20** |

**C-18 — the 96-character toast cutoff is measured in the wrong unit.**
Upstream's `selection.len()` (`src/gtk/actions/win_copy_val.rs:47,51`) is a
Rust `String`'s **byte** length. The port's `value.length`
(`lib/bobby/actions/win_copy_val.rb:83`, against `MAX_ANNOUNCED = 96`) is
Ruby's **character** count. For any non-ASCII value the two disagree: 50
accented characters are 100 bytes, so upstream copies them silently and the
port announces them; conversely nothing makes the port silent until 96
characters, where upstream is silent from 96 bytes. The fix is
`value.bytesize`. Unrecorded.

**C-19 — upstream has a user-visible string the port does not.**
`src/gtk/actions/win_copy_val.rs:52` builds `"Copied to clipboard"` as the
title for a value at or past the cutoff. Upstream then never shows it, because
the `add_toast` call sits behind the same `< 96` test — so upstream's long-copy
toast is dead code. The port has no such literal anywhere
(`grep -rn 'Copied to clipboard' lib/ test/` → nothing), so the string is
absent from the port's catalogue. One string, upstream, with no counterpart.

**C-20 — the toast is the only confirmation that a copy happened, and no check
asserts it.** `grep -ni toast test/drive_bobby.rb` returns exactly one line,
`the toast overlay is the content`. Across 428 checks nothing asserts:

- `Row %d copied to clipboard` — the title `win.copy-row` builds, one-based so it matches the index column (`win_copy_row.rb:65`)
- `<span font_features='tnum=1'>‘%s’  copied to clipboard</span>` — the tabular-figures markup `win.copy-val` builds (`win_copy_val.rb:98`)
- `timeout = 2` on either toast
- `overlay.dismiss_all` before each one, which is why holding Ctrl+C does not queue a toast per repeat
- `MAX_ANNOUNCED`, in either direction

The clipboard half of both actions is driven thoroughly (steps 26–33) and the
toast half is not driven at all. Two msgid-bearing strings and three behaviours
are therefore unverified. Per the gate's own rule, a component no check
exercises is unverified, not done. The port additionally escapes markup in the
toast title where upstream interpolates raw
(`win_copy_val.rb:29-36, 101`) — a located fix that changes no msgid, and also
unexercised.

Upstream behaviour the port does reproduce, confirmed by reading: `dismiss_all`
before every toast, timeout 2, the silent long copy, and the one-based row
number.

### Unit verdict: **gap** (C-18, C-19, C-20)

## Unit: sqlite backend — `src/bobby/sqlite/*.rs` → `lib/bobby/sqlite/*.rb`

| Item | Up | Port | Verdict |
|---|---|---|---|
| `Affinity` parse (declared type) | 5 rules, INT first | same order, driven (step 9) and specced | parity |
| `Affinity` from a read value | 5 arms incl. blob | ✓ driven (step 10), encoding-based blob arm | parity (C-05 closed) |
| `Affinity` Display, REAL | Rust `f64` shortest round-trip | Ruby `Float#to_s` | **gap C-17** |
| `Affinity` Display, other | ✓ | ✓ driven | parity |
| `Column` / `PRAGMA table_info` | ✓ | ✓ driven (step 6 of the backend set) | parity (`unique` hardcoded false on both) |
| `ColumnSeparator` 4 values + char aliases | ✓ | ✓ driven (step 11) | parity |
| `Table` / `TableName` / `has_row_id` | ✓ | ✓ driven (steps 8, 36–37) | parity |
| `Row#format_with` 4 separators | ✓ | ✓ driven (steps 28–31) | parity |
| `RowOrder` DESC default | ✓ | ✓ driven (steps 50–51) | parity |
| `Database` immutable URI, journal_mode probe, busy timeout, query_only, foreign_keys | ✓ | ✓ driven (step 12) | parity |
| `Database#data_version` | ✓ | ✓ driven | parity (unused on both) |
| `DatabaseCacheModel` paging | 256-row page, ±256 eviction, cached count | reads every row eagerly | **gap C-07** |

**C-07 — no lazy paging.** `lib/bobby/sqlite/cache.rb:61-69` builds a
`RowObject` for every row in the table and appends all of them to a
`Gio::ListStore` before the window appears, against upstream's
`gio::ListModel` whose `item(n)` fetches a 256-row page centred on `n` and
evicts anything beyond ±256 (`src/bobby/sqlite/cache.rs`). Admitted in the
right register in `FINDINGS.md` and in the class comment. It stays a gap, and
one consequence is not written down anywhere: the port ships
`data/studio.planetpeanut.Bobby.metainfo.xml` carrying upstream's own feature
line **`Scroll through tables and views of any size`**, which is the sentence
C-07 makes false. The app advertises the feature it lost.

### Unit verdict: **gap** (C-07, C-17)

## Unit: util — `src/gtk/util.rs` → `lib/bobby/util.rb`

| Function | Up | Port | Verdict |
|---|---|---|---|
| `widget_by_name` | ✓ | — | correspondence: the port's widgets are memoized accessors, so there is nothing to search for. Located: `window.rb:206-285`, `content.rb:99-144` |
| `find_column_view` | ✓ | — | same correspondence. Located: `window.rb#content`, `content.rb#column_view` |
| `copy_to_clipboard` | ✓ | ✓ | parity — `Gdk::Clipboard#set` for gtk-rs's `set_text`; round trip driven (steps 81–82) |

### Unit verdict: **parity**

## Unit: packaging and data — upstream root → port root

| Upstream | Port | Verdict |
|---|---|---|
| `data/studio.planetpeanut.Bobby.desktop` | byte-identical | parity |
| `data/studio.planetpeanut.Bobby.gschema.xml` | byte-identical, driven against the running app | parity |
| `data/gschemas.compiled` | present | parity |
| `data/studio.planetpeanut.Bobby.metainfo.xml` | byte-identical + one appended `<release>` | parity |
| `data/icons/**` (2 SVGs) | present, registered at runtime by `lib/bobby/icons.rb`, driven | parity (C-02 closed); the install step is C-11 |
| `LICENSE.txt` | present | parity (C-09 closed) |
| `data/screenshots/*.png` (4) | **absent** (`data/screenshots/` is an empty untracked directory) | **gap C-08** |
| GPLv3 header on every source file | **absent from all 47 `lib/**/*.rb`** | **gap C-10** |
| `meson.build`, `meson.options`, `data/meson.build`, `data/icons/meson.build` | absent — nothing installs the desktop file | **gap C-11** |
| `studio.planetpeanut.Bobby.yml`, `.devel.yml` | absent | **gap C-12** |
| `.github/workflows/flatpak.yml` | absent | **gap C-13** |
| `build-aux/dist-vendor.sh` | absent | **gap C-14** |
| `.github/CONTRIBUTING.md`, `info/release-steps.md` | absent | **gap C-15** |
| `.github/workflows/tests.yml` | present | parity |
| `README.md`, `Bobby.doap`, `.github/CODE_OF_CONDUCT.md`, `.github/FUNDING.yml` | present | parity |
| `Cargo.toml`, `Cargo.lock`, `.cargo/config.toml` | `bobby-rb.gemspec` + `nix/Gemfile.lock`; **no root `Gemfile.lock`** | **gap C-21** (see the test-parity report) |

**C-08 — the port still ships pictures of upstream's app.** The three
`<screenshot><image>` entries in the metainfo point at
`raw.githubusercontent.com/hbons/Bobby/main/data/screenshots/…`, which are
renders of the Rust build. `tmp/shots/` holds sixteen screenshots of this port,
taken by the drive in this very repository, so the obstacle `FINDINGS.md`
gives for this gap is false — see the accountability report.

**C-10 — no licence header on any source file.** Upstream carries a five-line
GPLv3 notice on all 34 `.rs` files. `grep -L -i 'GNU General Public'
lib/bobby/**/*.rb` returns all 47 files, while `bobby-rb.gemspec` declares
`GPL-3.0-or-later` and the about dialog shows `License::GPL_3_0`. `LICENSE.txt`
landing in `ca5cafa` closed half of C-09/C-10; this is the other half.

**C-11 — nothing installs the desktop file.** `lib/bobby/icons.rb` stands in
for the icon half of the install. The desktop entry is still only a file in the
repository, so Bobby does not appear in the app grid and a `.db` file has no
**Open With → Bobby**. The gschema half is worked around by a committed
`gschemas.compiled` and `Settings::SCHEMA_DIR`.

### Unit verdict: **gap** (C-08, C-10 … C-15, C-21)

---

## Summary

| Unit | Verdict |
|---|---|
| application | parity |
| window | **gap** (C-03, C-22, C-23) |
| content | parity |
| item | **gap** (C-17) |
| switcher | parity |
| main menu | parity |
| open button | parity |
| drop target | **gap** (C-23) |
| preferences dialog | parity |
| shortcuts dialog | parity |
| about dialog | parity |
| file dialog | **gap** (C-23) |
| actions | **gap** (C-18, C-19, C-20) |
| sqlite backend | **gap** (C-07, C-17) |
| util | parity |
| packaging and data | **gap** (C-08, C-10 … C-15, C-21) |

**14 open gaps. The three that change what a user sees are C-17 — a column of
integral REAL values reads `1.0` where upstream reads `1`, on screen, in the
tooltip and in the clipboard; C-07 — the port cannot scroll a table of any
size while its own metainfo says it can; and C-20 — the toast that tells the
user a copy succeeded is not asserted by one of the 428 checks.**
