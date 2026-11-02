# Translation parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe` |
| Port | `ruby` branch |
| Upstream `po/` | **none** — no catalogue, no POTFILES, no `gettext` |
| Port `po/` | none |
| Translatable strings upstream | 33 |
| Surviving in the port | **0** |
| Gaps | **2** |

## What translation means in this app

Upstream has no gettext at all. There is no `po/` directory, no `.pot`, no
`POTFILES.in`, no `gettextrs`/`gettext` dependency in `Cargo.toml`, and no `_()`
or `gettext(` anywhere in `src/`. Every one of the roughly sixty user-visible
UI labels is a hard-coded English literal in Rust — `"Browse Databases"`,
`"Unable to Open File"`, `"Preferences"`, `"Row Numbers"`, `"Copy Row"`,
`"Tables"`, `"Main Menu"`, and so on.

So the app's entire translated surface is its **AppStream and desktop
metadata**, where the translations are inline `xml:lang` attributes rather than
catalogue entries. `msgid-census.sh` finds all 33 strings and every single one
of them in two files:

```
data/studio.planetpeanut.Bobby.metainfo.xml   32 strings
data/studio.planetpeanut.Bobby.desktop         1 string
```

The port's census returns **nothing**, because the port ships neither file.
`data/` on `ruby` holds `gschemas.compiled` and
`studio.planetpeanut.Bobby.gschema.xml` and nothing else.

## Gap TR1 — every translated string in the project is gone

**Four languages, 15 translations, lost outright.**

| msgid | Upstream translations | Port |
|---|---|---|
| `View SQLite databases` (`<summary>`) | de `SQLite-Datenbanken anzeigen`, es `Ver bases de datos SQLite`, fr `Afficher les bases de données SQLite`, pt `Visualizar bancos de dados SQLite` | — |
| `database` (`<keyword>`) | de `Datenbank`, es `base de datos`, fr `base de données`, pt `banco de dados` | — |
| `sqlite` (`<keyword>`) | de/es/fr/pt `sqlite` | — |
| `table` (`<keyword>`) | de `Tabelle`, es `tabla`, pt `tabela` (no fr) | — |

The four `<summary xml:lang>` lines are what a German, Spanish, French or
Brazilian user reads under "Bobby" in GNOME Software. The 11 localised keywords
are what makes Bobby findable by typing "Datenbank" or "base de datos" into
that search box. All 15 are in a file the port does not have.

## Gap TR2 — the untranslated source strings are gone too

The same two files carry 18 further user-visible strings with no translation
yet, and they are equally absent. A missing msgid cannot be translated later,
so these are the same gap at a different stage.

From `data/studio.planetpeanut.Bobby.metainfo.xml`:

| | |
|---|---|
| Name / summary | `Bobby`, `View SQLite databases` |
| Description | `Bobby lets you open SQLite database files (.db, .sqlite) and browse the tables inside. Handy for app development or inspecting downloaded databases.`, `Don't forget to sanitize your database inputs!` |
| Feature list | `Scroll through tables and views of any size`, `Copy rows or cells to the clipboard`, `Made with care by a human` |
| Screenshot captions | `Browse SQLite files`, `Preferences dialog`, `Empty page` |
| Developer | `Hylke Bons` |
| Keywords (source) | `database`, `sqlite`, `table`, `sql`, `query`, `row`, `column`, `cell`, `gnome`, `gtk` |
| Release notes | 8 releases × 3 bullets = 24 further strings the census folds in |

From `data/studio.planetpeanut.Bobby.desktop`:

| | |
|---|---|
| `Name=Bobby` | the name under the icon in the app grid |

Note that `Scroll through tables and views of any size` is also the feature
`component-parity.md` G2 reports as unbuilt — the port would be shipping a
claim it does not meet, which is the second reason to fix G2 before copying
this file.

## Fix

1. Copy `data/studio.planetpeanut.Bobby.metainfo.xml` verbatim, including all
   four `xml:lang` summaries and all 11 localised keywords, then append a
   `<release>` for the port's version. Validate with
   `appstreamcli validate`.
2. Copy `data/studio.planetpeanut.Bobby.desktop` verbatim and install it.
   Validate with `desktop-file-validate`.
3. Byte-compare both against upstream afterwards. A retyped `msgid` discards
   every language's translation of it while the English still reads correctly,
   which is the failure mode that survives any screenshot review.

## Not a gap in this ledger — the UI is untranslated on both sides

The port hard-codes English UI literals exactly as upstream does, and
`component-parity.md`'s text axis confirms every one of them is
byte-identical: `Browse Databases`, `Drag and drop <b>SQLite files</b> here`,
`Unable to Open File`, `File is not a <b>SQLite database</b> or encrypted`,
`Could not open a database connection`, `Table list empty`,
`Table does not exist`, `File has changed`, `Reload`, `Open...`, `Main Menu`,
`Tables`, `Views – n`, `Tables – n`, `Preferences`, `Keyboard Shortcuts`,
`About Bobby`, `Rows &amp; Columns`, `Appearance`, `Row Numbers`, `Row Order`,
`Newest First`, `Oldest First`, `Column Separator`,
`Used when copying rows to the clipboard`, `Tabs`, `Spaces`, `Commas`,
`Markdown`, `Monospace Font`, `General`, `Open File`, `Open Menu`,
`Reload Window`, `Close Window`, `Quit`, `Copy Row`, `Copy`,
`Row n copied to clipboard`, `copied to clipboard`, `SQLite Databases`,
`All Files`, `Cannot run as root`,
`Could not read HOME environment variable`,
`Selected file has no local path`, `Usage: bobby [file]...`,
`    --help, --version, --deps, --env`, `NULL`, `PRIMARY_KEY`, `n BYTES`,
`???`, `—`, `◇`.

Two formatting details the port got right rather than interpolating blind:

- `Row #{row_number} copied to clipboard` (`actions/win_copy_row.rb:70`) and
  `‘#{value}’  copied to clipboard` (`actions/win_copy_val.rb:102`) are
  interpolated, as upstream's `format!` strings are. **If either side ever adds
  gettext these become the `format(_("Row %d copied to clipboard"), n)` case**
  the skill warns about, so the shape is worth remembering. Today neither side
  marks them, so they are at parity.
- `Rows &amp; Columns` keeps upstream's escaped ampersand
  (`dialogs/preferences.rb:95`), because Adwaita parses group titles as markup.
  Unescaping it would have rendered as `Rows  Columns`.

Adding gettext to the port ahead of upstream is not owed by this ledger and
would break msgid identity against a future upstream catalogue. Leave it.
