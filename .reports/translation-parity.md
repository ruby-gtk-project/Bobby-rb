# Translation parity — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe150c215553fce1d1d8ec2ce42e45d89ad` |
| Port | `ruby` @ `28bb3a5eec99ec3b5543f00e902cf10d00ba0fe9` |
| Domain | **none** — neither tree has a gettext domain |
| Upstream messages (distinct keys) | 33 |
| Port messages | 33 |
| Ported | **33** |
| Gaps | **0** |
| Extra in the port | 0 |
| Languages upstream ships | **0** `.po` files |
| Languages the port ships | 0 |
| Unresolved markers | 0 on either side |

## The census

```
$ msgid-census.sh <upstream> | wc -l   → 33
$ msgid-census.sh <port>     | wc -l   → 33
$ diff <(cut -f1,2 upstream-msgids.tsv|sort -u) <(cut -f1,2 port-msgids.tsv|sort -u)
(no output)
```

The two key sets are byte-identical. No message has a context on either side;
none is plural; no marker takes a non-literal argument, so there is nothing to
census by hand.

## Where the 33 messages come from

All of them come from the three non-code sources, and **none from source
code**:

| Source | Messages |
|---|---:|
| `data/studio.planetpeanut.Bobby.metainfo.xml` | 32 |
| `data/studio.planetpeanut.Bobby.desktop` | 1 (`Name=Bobby`) |
| `data/studio.planetpeanut.Bobby.gschema.xml` | 0 — the schema declares no `<summary>` or `<description>` |
| `src/` / `lib/` | 0 |

Both data files were diffed against upstream directly, which is a stronger
check than the census:

```
diff up/data/studio.planetpeanut.Bobby.desktop      data/...desktop       → identical
diff up/data/studio.planetpeanut.Bobby.gschema.xml  data/...gschema.xml   → identical
diff up/data/studio.planetpeanut.Bobby.metainfo.xml data/...metainfo.xml  → one added <release version="0.1.0">
```

The added `<release>` block contributes no msgid: xgettext's ITS rules for
AppStream exclude `<release>` notes, and the census agrees — 33 on both sides.

The 32 metainfo messages break down as 18 source strings
(`<name>`, `<summary>`, `<p>`, three `<caption>`s, six `<keyword>`s, the three
feature `<li>`s, the developer name) and 15 pre-localised strings already
carried in the file as `xml:lang` variants: 4 translated `<summary>` lines
(de, es, fr, pt) and 11 translated `<keyword>` entries. Every one of those
survived the copy, because the file was copied rather than retyped. That is
the whole reason this axis is clean, and it is worth stating plainly: a port
that had re-authored the metainfo by hand would have silently dropped four
languages' worth of donated work, and the English would have looked perfect.

## The thing this ledger cannot make clean

**Neither app is internationalised at all.** Upstream has:

- no `po/` directory, no `LINGUAS`, no `.pot`
- no `gettext` dependency in `Cargo.toml`
- no `i18n.gettext()` in `meson.build`
- not one `_()`, `gettext!`, `tr!` or equivalent in 3,410 lines of Rust

So every user-visible string in the running application — `Browse Databases`,
`Drag and drop <b>SQLite files</b> here`, `Unable to Open File`,
`File has changed`, `Reload`, `Open...`, `Preferences`, `Keyboard Shortcuts`,
`About Bobby`, `Tables`, `Main Menu`, `Copy`, `Copy Row`, `Views – %d`,
`Tables – %d`, `Row Numbers`, `Row Order`, `Column Separator`,
`Monospace Font`, `Rows &amp; Columns`, `Appearance`, the six shortcut labels,
`Newest First`, `Oldest First`, `Tabs`, `Spaces`, `Commas`, `Markdown`,
`SQLite Databases`, `All Files`, `Row %d copied to clipboard`,
`Copied to clipboard`, `File is not a <b>SQLite database</b> or encrypted`,
`Could not open a database connection`, `Table list empty`,
`Table does not exist`, `Cannot run as root` — is a bare literal in the source
of both apps, reaches no catalogue, and is English only.

The port reproduces that faithfully and byte-for-byte: every one of those
strings was compared against upstream's during the component-parity pass and
every one matches, including the escaped `&amp;` in the preferences group
title, the `–` en dashes in the switcher's section headers, the `…` in the
blob tooltip, the `◇` primary-key marker and the `—` em dash placeholder. Had
any of them been reworded, it would be a gap here even with no catalogue to
break, because the msgid is the thing the port owes.

**Parity is 33/33 and it is met. The port inherits no translations because
there are none to inherit, and it inherits no way to add any.** That is
upstream's debt, not the port's, and this ledger records it rather than
closing it: the day upstream grows a `po/` directory, the port has 40-odd
unmarked literals to find.

## Rules check

| Condition | Result |
|---|---|
| The key sets are equal | ✓ 33 = 33, `diff` empty |
| Each key is byte-identical | ✓ |
| The languages come with it | ✓ 0 of 0 `.po` files; the 15 `xml:lang` metainfo variants all survived |
| `kind` matches on every shared key | ✓ all 33 `single` on both sides |
| Uses per message | 1 for all 33 on both sides; no reuse to lose |
| Unresolved markers | 0 |

**No gaps.**
