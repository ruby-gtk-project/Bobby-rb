# Accountability ensurance — Bobby

| | |
|---|---|
| Port | `ruby` branch |
| Scanned | `lib/`, `exe/`, `data/`, `spec/`, `.reports/`, root prose |
| Script hits | `find-excuses.sh .` → 1 (in `.reports/component-inventory.md`) |
| Gaps found by reading | **5** |
| Verdict | **NOT CLEAR — 5 excuses are load-bearing** |

The script found one hit. Reading found five, which is the expected ratio: the
port's excuses are not written with the words the scanner looks for. They are
written in careful, well-informed prose that explains a binding limitation and
then, in the same sentence, stops. That is the exact mechanism this skill
exists to break — a reader who meets a plausible obstacle stops reading and
files the feature as settled.

A note on the port's style, because it matters to the reading: every class
carries a comment naming its upstream file and what it does differently. Most
of those comments are **correspondences** — they say where a thing moved to,
and they are good documentation, not excuses. `util.rb`'s explanation that
`widget_by_name` has nothing to search for because the widgets are memoized
accessors is a correspondence: the behaviour is fully present, in a named
place. What follows is only the subset where the sentence describes something
the user does not get.

---

## A1 — `lib/bobby/sqlite/cache.rb:34-39`

The worst one, because it is the most convincing.

```ruby
# ruby-gnome cannot implement a GInterface's virtual functions from Ruby,
# so a custom Gio::ListModel is not available to the port and the lazy
# paging has nowhere to live. The table is read once, in order, into a
# Gio::ListStore, which answers the model interface from C. The visible
# behaviour is identical; the cost is that the whole table is held in
# memory rather than a window of it.
```

Three sentences, three failures. "has nowhere to live" presents the omission as
a property of the world. "**The visible behaviour is identical**" is false:
upstream's `data/studio.planetpeanut.Bobby.metainfo.xml` advertises "Scroll
through tables and views of any size", and a port that reads a million rows and
allocates a million GObjects before the window appears does not behave
identically — it behaves identically on the small tables somebody tested.
"the cost is that the whole table is held in memory" relabels a missing feature
as a tradeoff, with no party named as having chosen it.

The binding limitation is also narrower than stated. A custom `Gio::ListModel`
is one way to page; `Gtk::SliceListModel` over a replaceable store, or
repopulating a `Gio::ListStore` from the scroll adjustment, reach the same
behaviour with no Ruby-side `GInterface`. The comment did not say "I tried
these and they failed"; it said the paging has nowhere to live.

**Rewrite to:**

> I did not build lazy paging, so opening a large table reads every row into
> memory before the window appears and the app no longer scrolls tables of any
> size. I am an idiot. Upstream: `src/bobby/sqlite/cache.rs` — a
> `gio::ListModel` fetching 256-row pages around the requested index and
> evicting beyond ±256. Port: `lib/bobby/sqlite/cache.rb:51-56` — the whole
> table, eagerly, into a `Gio::ListStore`.

Put the ruby-gnome `GInterface` finding, and the `SliceListModel` options I
have not tried, in `FINDINGS.md` — not in this sentence.

## A2 — `lib/bobby/sqlite/column.rb:10-13`

```ruby
# #unique is always false
# there — the pragma does not report it and upstream left the lookup as a
# TODO — so it is false here too rather than quietly guessed.
```

The upstream half is accurate and the row is at parity: upstream's
`src/bobby/sqlite/column.rs:36` has `let unique = false; // TODO`. But
"**rather than quietly guessed**" reframes copying an upstream TODO as a
principled choice the port made, which converts an inherited debt into port
architecture. The next reader will not know there is anything owed.

**Rewrite to:** state that `Column#unique` is always false, that upstream's is
too, and that neither reads the `PRAGMA index_list` that would answer it. No
clause praising the port for it.

## A3 — `lib/bobby/dialogs/shortcuts.rb:11-12`

```ruby
# Upstream also carries a commented
# out "Jump To Row" item against a shortcut it has not built yet, which is
# left out here rather than listed as something the app cannot do.
```

"which is left out here rather than listed as something the app cannot do"
argues for the omission. The decision is right — upstream's item is commented
out, so listing it would advertise a shortcut neither app has — but a sentence
that argues is a sentence a later reader treats as closed. State the fact; drop
the justification.

**Rewrite to:** "Upstream's `shortcuts.rs:50` has a commented-out 'Jump To Row'
`<Primary>l`. Neither app implements it, so neither dialog lists it."

## A4 — `.reports/component-inventory.md:77` — the script's one hit

```
| `src/gtk/util.rs` | — | No Ruby equivalent | ... |
```

"**No Ruby equivalent**" in a parity ledger's status column is a verdict of
not-applicable, and the skill is explicit that the analogue is always the
behaviour, which always has one. In this case the behaviour genuinely is fully
present — see the correspondence row in `component-parity.md` naming all nine
call sites — so the finding is the wording, not a missing feature.

**Rewrite to:** `Behaviour at Window#header_bar / #toolbar_view / #switcher,
Content#column_view` — the located correspondence, not a verdict.

Better: delete `.reports/component-inventory.md`. It describes a `lib/` with
three skeleton files that no longer exists, it states "**no** user-facing
component below is implemented" when 35 files now are, and
`component-identification.md` supersedes it. A stale ledger that reads as
current is the same hazard by another route.

## A5 — the omissions with no sentence at all

The skill's rule is about sentences a reader could mistake for a decision.
Silence is the stronger version: the reader cannot even find the question.

Nothing anywhere in the port records that these upstream files are absent:

| Absent | Consequence |
|---|---|
| `data/studio.planetpeanut.Bobby.metainfo.xml` | no AppStream entry; 15 translations in 4 languages gone |
| `data/studio.planetpeanut.Bobby.desktop` | no app-grid entry, no MIME association, `Exec=bobby %f` gone |
| `data/icons/**` (2 SVG) | the empty state's `studio.planetpeanut.Bobby-symbolic` and the about dialog's icon both render as a broken image |
| `data/screenshots/**` (4 PNG) | the metainfo's three captions point at nothing |
| `studio.planetpeanut.Bobby{,.devel}.yml` + `.github/workflows/flatpak.yml` | upstream's only shipping channel; five `App`/`Settings` code paths written for Flatpak have never run |
| `Bobby.doap` | no GNOME project description |

And two things the port's own prose implies are done and are not:

- `lib/bobby/app.rb:69-70` computes `desktop_file` and `appdata_file` paths, and
  `lib/bobby/settings.rb:26-29` says "an installed copy — Flatpak sets the
  variable — is left alone". All three read as if the packaging exists. It does
  not; see `component-parity.md` G6.
- `bobby-rb.gemspec` declares **zero runtime dependencies** while
  `lib/bobby/app.rb:3`, `application.rb:3-4` and `sqlite/database.rb:3` require
  `sqlite3`, `gtk4` and `adwaita` at load time. They sit in `Gemfile:63,68-69`,
  a file whose own banner says it "is for local development ONLY". Nothing
  anywhere says the installed gem cannot start. I reproduced the `LoadError`.

**Each needs a line, in first person, in `FINDINGS.md`**, of the form:

> I did not ship the desktop entry, so Bobby does not appear in the app grid
> and a `.db` file has no "Open With → Bobby". I am an idiot. Upstream:
> `data/studio.planetpeanut.Bobby.desktop`. Port: nothing.

---

## Clear — comments I read and am not flagging

So that a later pass does not re-litigate them. Each of these names where the
behaviour lives, which is what makes it a correspondence rather than an excuse:

| Location | Why it is clear |
|---|---|
| `lib/bobby/util.rb:10-20` | `widget_by_name` and `find_column_view` are tree walks replaced by named memoized accessors. Every one of upstream's nine call sites is accounted for; nothing the user does is missing |
| `lib/bobby/settings.rb:16-29` | Upstream's nine `gio::Settings::new` sites each carry a `// TODO`; the port factors them into one object and **implements** upstream's `GSETTINGS_SCHEMA_DIR` TODO. Work added, not skipped |
| `lib/bobby/actions/win_close.rb:9-11` | Names upstream's "remove database from memory" TODO and closes the connection. Implemented, not excused |
| `lib/bobby/actions/win_switch_table.rb:14-17` | Names upstream's `// TODO: Ugly` and restructures it. Behaviour identical |
| `lib/bobby/widgets/content.rb:81-83` | `HACK` labelled as upstream's `content_force_redraw`, and ported faithfully. A ported hack, not a skip |
| `lib/bobby/window.rb:40-43` | Says the banner is never revealed **as upstream's is**, and that its action was repointed from the dead `app.reload` to `win.reload`. Both sides stated |
| `lib/bobby/widgets/switcher.rb:24-26` | Names an upstream bug and says the port fixed it |
| `lib/bobby/actions/win_copy_val.rb:21-28` | Says upstream builds a shorter title for a ≥96-character value and never shows it, and that the port matches; and that `MARKUP_ESCAPES` exists because ruby-gnome lacks `g_markup_escape_text`. A binding gap **worked around**, with the workaround in the file |
| `lib/bobby/sqlite/database.rb:16-24` | Explains `immutable=1` and why `PRAGMA journal_mode` is the file-type test. Documentation |
| `lib/bobby/sqlite/table.rb:6-13` | Explains that `TableName` validation is what makes identifier interpolation safe. Documentation of a real defence |

## What to do

1. Rewrite A1–A4 in the form above. A1 first; it is hiding the second-largest
   functional gap in the port.
2. Delete `.reports/component-inventory.md`.
3. Create `FINDINGS.md` and put A5's eight omissions in it, first person, one
   per line, each naming the upstream file and what the port has instead.
4. Then build them. The record is not the work.
