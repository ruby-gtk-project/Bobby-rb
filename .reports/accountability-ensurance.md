# Accountability ensurance — Bobby

| | |
|---|---|
| Upstream | `origin/main` @ `5ea72fe` |
| Port | `ruby` @ `28bb3a5` |
| `find-excuses.sh` hits in prose and code | **0** outside `.reports/` |
| Marker grep over `lib/`, `exe/`, `spec/` | 14 hits, **13 of them describing upstream's TODOs**, 1 soft hit |
| Gaps found with no record anywhere | **5** |
| False statements in `FINDINGS.md` | **2** |

## The scans

```
$ find-excuses.sh .
.reports/accountability-ensurance.md:107  No Ruby equivalent
.reports/accountability-ensurance.md:110  No Ruby equivalent
.reports/accountability-ensurance.md:169  skipped
```

Three hits, all in this report's own previous revision quoting the skill's
own hit table. Nothing in `README.md`, `FINDINGS.md`, `AGENTS.md`,
`CHANGELOG.md`, `CLAUDE.md`, `SECURITY.md` or any source file.

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|XXX|HACK|unimplemented|placeholder|later|deferred|stub' lib exe spec
```

Fourteen hits. Thirteen are the port describing what **upstream's** TODO was
and what the port built instead — `window.rb:42`, `util.rb:13`,
`settings.rb:18,22,53`, `win_switch_table.rb:15`, `win_close.rb:10-11`,
`about.rb:10`, `content.rb:81` (an upstream `HACK` reproduced on purpose),
plus three `PLACEHOLDER` constant references in `affinity.rb` and one
`stub_env` mention in `spec/README.md`. Those are navigation, not excuses, and
every one of them names the behaviour the port has in place of the TODO. They
stand.

`FINDINGS.md` itself is in the right register throughout: first person,
admission first, the stupidity slot filled with stupidity and nothing else,
upstream and port cited with file:line. Seven open entries, four closed ones,
and a separate bindings section. That is the format working.

So the usual failure — a paragraph laundering a skip into a decision — has not
happened here. The failure that *has* happened is the other one.

---

## What is missing from the record

### Three defects nobody wrote down, two of which break a shipped feature

These were found by running the port, not by reading it. They are in no
document, no comment and no test.

> I did not make a BLOB cell show its size — a table of binary data shows raw
> bytes where upstream shows `2 BYTES`, the cell is not dimmed, the tooltip
> says `TEXT` instead of `BLOB 41 42 …`, and a blob whose bytes are not valid
> UTF-8 raises inside the bind handler so **the table does not draw at all** —
> because I am an idiot who tested a class the database layer never produces.
> Upstream: `src/bobby/sqlite/row.rs:72-78` maps `ValueRef::Blob(b)` to
> `Affinity::BLOB(len, hex_preview)`; `affinity.rs` Display renders
> `{length} BYTES`.
> Port: `lib/bobby/sqlite/affinity.rb:60` matches `when SQLite3::Blob`, and
> the `sqlite3` gem returns blobs as plain `ASCII-8BIT` `String`. Proven:
> `classes: [String, …] encodings: ["ASCII-8BIT", …]`,
> `type=text to_s="\xDE\xAD" dimmed=false tooltip="TEXT \xDE\xAD"`.
> The crash path is `lib/bobby/widgets/content.rb:225` →
> `lib/bobby/widgets/item.rb:103` → `:120` → `:34`
> (`Encoding::UndefinedConversionError: "\xDE" from ASCII-8BIT to UTF-8`).
> `spec/bobby/sqlite/affinity_spec.rb:72` and `:120` are green because they
> build the blob by hand, which is the part that makes this my fault and not
> bad luck.

> I did not make Copy work. Ctrl+C copies nothing, the context menu's **Copy**
> and **Copy Row** copy nothing, and the toast still says it worked — because
> I am too stupid to check a method name against the bindings I was writing
> against.
> Upstream: `src/gtk/util.rs:copy_to_clipboard` → `clipboard.set_text(s)`.
> Port: `lib/bobby/util.rb:27` calls `display.clipboard.set_text(text)`.
> `Gdk::Clipboard` has no `set_text`; driving the real `win.copy-row` action
> gives `undefined method 'set_text' for an instance of Gdk::Clipboard`. The
> method that exists is `#set`. Copying is one of the three features the
> metainfo advertises (`Copy rows or cells to the clipboard`).

> I did not make `bobby --version` work without a display, so the four CLI
> options die with a GTK backtrace on any headless machine, which is most of
> the machines that would run `--version`.
> Upstream: `src/main.rs:36-46` parses the arguments before `gui_run()`, and
> `gtk_init` only happens inside `app.run()`.
> Port: `exe/bobby:4` requires `bobby`, `lib/bobby.rb:3` requires
> `bobby/application`, and the `gtk4` gem calls `gtk_init` at require time.
> Measured: no display → exit 1 and a `Gtk::InitError` trace; with
> `gtk4-broadwayd` running → `bobby 0.1.0`, exit 0.

### Two more, smaller, equally unrecorded

> I did not put `sqlite3` in `nix/Gemfile`, so the port cannot be loaded in
> its own documented development environment or started from its own Nix
> package, and I am an idiot who wrote a comment claiming that file "holds the
> gemspec's runtime dependencies only" while it holds two of the three.
> Port: `nix/Gemfile:11-12` lists `adwaita` and `gtk4`;
> `bobby-rb.gemspec:121` declares `sqlite3`; `lib/bobby/app.rb:3` and
> `lib/bobby/sqlite/database.rb:3` require it at load time.
> Measured: `nix develop --command ruby -Ilib -e 'require "bobby"'` →
> `cannot load such file -- sqlite3 (LoadError)` at `lib/bobby.rb:3`.
> `flake.nix:102` builds `packages.default` from the same bundle.

> I did not ship a licence. There is no `LICENSE`, no `COPYING` and no
> copyright header on any of the 31 files in `lib/` — for a GPLv3 program
> whose gemspec says `GPL-3.0-or-later` and whose about dialog says
> `License::GPL_3_0` — because I am an idiot who copied the data files and not
> the one file that says anyone may have them.
> Upstream: `LICENSE.txt`, plus a five-line GPLv3 header on all 34 `.rs` files.
> Port: nothing.

### Two divergences recorded only in a class comment

Neither is a defect; both are the port deliberately differing from the spec,
and `FINDINGS.md` is where a reader looks for that.

- The reload banner. Upstream `src/gtk/windows/window.rs:350` targets `app.reload`, an action that exists nowhere upstream, so upstream's banner button is inert. The port targets `win.reload` (`lib/bobby/window.rb:214`) and works. Said in a comment at `window.rb:42-43`, nowhere else.
- `Gtk::Application` standing in for `Adw::Application` (`lib/bobby/application.rb:40-42`). The sibling substitution for `Adw::ApplicationWindow` **is** in `FINDINGS.md`; this one is not.

Also unrecorded, and visible: the port resets `toolbar_view.top_bar_style` to
`:flat` when leaving the content state (`window.rb:117`, `:127`); upstream
never sets it back.

---

## Two statements in `FINDINGS.md` that are not true

This is the part that matters most, because both of them are reasons a future
agent would not try again.

**1.** Under *Still missing*:

> "I could not take them, because this machine has no GTK 4 or libadwaita
> (`pkg-config --modversion gtk4` fails), so the app cannot be started at all
> here."

`pkg-config --modversion gtk4` fails in the bare shell and answers **4.22.4**
inside `nix develop`, which `CLAUDE.md` names as the setup step. GTK 4.22 has
no offscreen backend, so `gtk4-broadwayd :N` plus
`GDK_BACKEND=broadway BROADWAY_DISPLAY=:N` is what the `ruby-gtk-testing`
skill's "no Xvfb needed" needs on this box. The app started on the first
attempt. **The screenshots were takeable all along**, which converts
`screenshot-default.png` and friends from "cannot" to "did not".

**2.** Under *Fixed this round*:

> "I have not seen the three window states render, because there is no GTK 4
> on this machine to render them."

All three render, and were photographed: the empty state (with the status
page icon falling back to a broken-image placeholder, because nothing installs
`data/icons/`), the content state (with the blob defect above plainly visible
as `AB` where upstream shows `2 BYTES`) and the error state (`Unable to Open
File` with the markup bold intact). The preferences and shortcuts dialogs were
photographed too and match upstream item for item.

Neither sentence is an excuse in the skill's sense — both are first person and
both admit the omission. They are worse than an excuse in one respect: they
are **false in a way that forecloses the work**. A reader who believes the
machine cannot run GTK does not try, and the two crash-level defects above
survive another round for exactly that reason. The verification section's
honest list of what was and was not run is undermined by the same error:
"Not performed, because the tools are absent from this machine: … starting the
app." The tools were present.

## One soft hit worth rewriting

`lib/bobby/sqlite/column.rb:9-13`:

> "`#unique` is always false. Upstream's is always false too — `column.rs:36`
> is `let unique = false; // TODO`. Neither app reads `PRAGMA index_list`,
> which is the pragma that would answer whether a column is unique."

Parity genuinely holds — the field is dead on both sides and no UI reads it.
But "upstream does this too" is on the skill's hit list for a reason: the
sentence is written so a reader files the behaviour as settled rather than as
a debt both projects carry. Two words fix it: say that **neither app tells the
user which columns are unique, and the port owes that the moment upstream
builds it**, rather than that neither app reads the pragma.

## Where the accountability actually failed

Not in the prose. `FINDINGS.md` is the most honest document in this
repository and the format is doing its job on the seven gaps it names.

It failed in **scope**. The document covers what the author knew he had
skipped — packaging, paging, screenshots, the lockfile — and covers it well.
It does not cover what he never found out, because he believed he could not
run the app, and the suite that would have told him instead cannot be invoked
from the repository at all (see the test-parity report). So the record is
complete about the known unknowns and silent about two defects that break
shipped features in the first thirty seconds of use.

A record that is honest about everything it looked at, and did not look, reads
exactly like a record of a finished port. That is the same failure the skill
exists to kill, arriving by a different door.
