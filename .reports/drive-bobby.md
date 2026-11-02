# Driving the port: what running it found

`test/drive_bobby.rb` builds the real application, opens real SQLite files into
it and asserts the observable result of every action, dialog, menu and
accelerator the port claims to have. It is run with:

    nix develop --command xvfb-run -a ruby test/drive_bobby.rb

It ends in `428 of 428 checks passed` / `DRIVE OK` and writes sixteen
screenshots under `tmp/shots/`.

## Bugs the first runs found, and the fixes

1. **`Gio::Application#open` cannot be called from Ruby.** ruby-gnome has no
   marshaller for a C array of GFile:

       NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(interface)](GFile)

   The same gap makes `Gdk::FileList.new` unusable. Both the drop target
   (`lib/bobby/widgets/drop_target.rb`) and the file dialog
   (`lib/bobby/dialogs/file.rb`) routed their files through that call, so
   drag-and-drop and "Open..." had never opened a file. Both now hand their
   files to `Bobby::Application#open_files`, which is the body of the handler
   GIO itself calls for the "open" signal, so every route still arrives at the
   same place. The "open" signal path from the command line is unaffected: GIO
   emits it, Ruby never calls it.

2. **The table's rows were collected out from under the list model.**
   `Sqlite::RowObject` is a `GLib::Object` subclass holding its `Row` in a Ruby
   instance variable, and ruby-gnome associates the Ruby half with the GObject
   only weakly. Nothing on the Ruby side referred to the objects once
   `Cache.model_for` returned, so a garbage collection left a store full of
   GObjects whose `#row` came back `nil` — a table rendering blank, and with a
   few hundred rows a segfault inside the bind handler. `Sqlite::Cache` now
   keeps the `RowObject`s it built and `Widgets::Content` keeps the cache.

3. **Changing a preference while a window showed an error killed the process.**
   `row-order` and `monospace-font` reload the active window; a window in its
   error state has no database, and `Window#reload` reached into it anyway. The
   `NoMethodError` came out inside the GSettings handler, which ends the
   process. Upstream's `window_reload` leaves with `Err` there and every caller
   discards it; `Window#reload` is now that nothing.

4. **A closed window stayed in the application's list.** GTK4's
   `gtk_window_close` unmaps the window and takes it off the application
   **without emitting "destroy"**, so the port's destroy handler never fired and
   a closed window was still a candidate for the next file opened — which would
   have been loaded into a window nobody could see. `Application` now watches
   `close-request` as well as `destroy`.

5. **Leaving the content state kept the old table.** `show_empty_state` and
   `show_error_state` left `@content` and its widget in place, so `win.copy-row`
   on an emptied window still copied from the table it used to show, and the
   next table was appended below the old one. Both states now drop the content.

## Binding gaps, recorded rather than worked around

- `Gdk::FileList.new([...])` and `Gio::Application#open([...], hint)` both raise
  `NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(interface)](GFile)`.
  A `Gdk::FileList` therefore cannot be constructed from Ruby at all, so the
  drop target's accepting branch cannot be driven end to end: the drive asserts
  the controller's formats, its action and its opener, and emits a drop of a
  value that is not a file list to cover the refusing branch, but the branch
  that opens a dropped database is reachable only from a real pointer drag.
- `Gio::SettingsSchema#list_keys` and `Gio::Settings#list_keys` are not bound;
  `#has_key?` is, and is what the drive uses.
- `Gtk::FileDialog#open_multiple` is asynchronous and raises on cancel, so the
  chooser itself is not driven. Its filters are asserted by matching
  `Gio::FileInfo`s against them, and the code behind its callback is covered
  through `Application#open_files`.

## Two hazards of the harness itself

- Forcing a garbage collection while widget wrappers are live segfaults
  ruby-gnome. The drive forces one only around the plain `Sqlite::Cache`
  objects, which is where the lifetime bug above lives.
- An Adwaita dialog presented over a `Gtk::ApplicationWindow` rather than an
  Adwaita one falls back to a window of its own. It is therefore a second
  toplevel, and a screenshot of the main window shows nothing of it — the
  dialog shots are taken of `dialog.root`.

## The spec suite

`spec/spec_helper.rb` requires `kettle/test/rspec`, part of the kettle-dev
development bundle, which is not in the flake's gem set (nix/Gemfile carries the
gemspec's runtime dependencies only). The command the dev-shell banner prints
therefore fails to load, and `bundle exec rspec` cannot resolve the bundle here.
Run without that harness the suite passes:

    nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--options","/dev/null","--format","progress","spec/bobby/sqlite/affinity_spec.rb"])'
    25 examples, 0 failures
