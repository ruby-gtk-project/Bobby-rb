# frozen_string_literal: true

# Drives the whole app headlessly: builds the application and its window,
# opens a real SQLite file into it, walks every table and view, right-clicks a
# cell, copies a row and a value to the clipboard and reads them back, opens
# every dialog and menu, fires every action and every accelerator the port
# registers, reaches both failure states, and screenshots each one.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and the Ruby bindings
# differ from the C and Rust APIs in ways only a run reveals — the first run of
# this script found that `Gio::Application#open` cannot be called from Ruby at
# all (ruby-gnome cannot marshal a C array of GFile), which meant the port's
# drag-and-drop and its "Open..." dialog had both never opened a file.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_bobby.rb
#
# xvfb-run is not optional here: the gtk4 gem runs gtk_init while it is being
# required, and gtk_init fails outright with no display.
#
# The specs under spec/ cover the display-free half. What is driven here is
# everything that needs a widget, a main loop or a real database file.

require "fileutils"
require "stringio"
require "tmpdir"

# Scratch directories, so a run never reads or writes the real ones, and the
# in-memory GSettings backend, so changing a preference does not touch dconf.
SCRATCH = Dir.mktmpdir("bobby-drive")
ENV["XDG_CONFIG_HOME"] = File.join(SCRATCH, "config")
ENV["XDG_DATA_HOME"] = File.join(SCRATCH, "data")
ENV["XDG_CACHE_HOME"] = File.join(SCRATCH, "cache")
ENV["GSETTINGS_BACKEND"] = "memory"
ENV.delete("DEBUG")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "bobby"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

# --- Fixtures ---------------------------------------------------------------

# One ordinary table with every affinity in it, one WITHOUT ROWID table whose
# name carries the underscore the switcher has to escape, and one view, so
# Table's three-valued has_row_id and Row's two queries are both exercised.
# 47 x U+00E9: 47 characters, 94 bytes, so it is under the 96 the long-copy
# cutoff counts. One more character takes it to 96 bytes while leaving it 48
# characters long, which is what tells a byte count from a character count.
ANNOUNCED_NOTE = "\u00E9" * 47
SILENT_NOTE = "\u00E9" * 48

MAIN_DB = File.join(SCRATCH, "fixture.db")
SQLite3::Database.new(MAIN_DB) do |db|
  db.execute(<<~SQL)
    CREATE TABLE people (
      id INTEGER PRIMARY KEY,
      name TEXT,
      score REAL,
      data BLOB,
      note VARCHAR(255),
      rating NUMERIC
    );
  SQL
  # The three scores are the three REAL values that render differently in the
  # two apps unless the port formats them the way Rust's Display for f64 does:
  # an integral one with no trailing ".0", a very large one in full rather than
  # as an exponent, and a fractional one, which is the only one Ruby already
  # agreed with upstream about.
  #
  # The two notes are the long-copy cutoff, which upstream counts in bytes:
  # ANNOUNCED_NOTE is 47 accented characters and 94 bytes, so both apps
  # announce it, and SILENT_NOTE is 48 of them and 96 bytes, so neither does —
  # though a port counting characters would have announced it.
  db.execute("INSERT INTO people VALUES (1, 'Ada <&>', 1.0, X'DEADBEEFCAFE0102', NULL, 7)")
  db.execute("INSERT INTO people VALUES (2, 'Bob', 1e300, NULL, ?, NULL)", [ANNOUNCED_NOTE])
  db.execute("INSERT INTO people VALUES (3, 'Cy', 3.5, NULL, ?, 9)", [SILENT_NOTE])
  db.execute("CREATE TABLE audit_log (key TEXT PRIMARY KEY, msg TEXT) WITHOUT ROWID")
  db.execute("INSERT INTO audit_log VALUES ('k1', 'first message')")
  db.execute("INSERT INTO audit_log VALUES ('k2', 'second message')")
  db.execute("CREATE VIEW people_view AS SELECT name, score FROM people")
  # Enough rows to be scrollable, so win.reload's carrying of the scroll
  # offsets across a reload is something that can actually be observed. The
  # name sorts last, which keeps every other table's index where it was.
  db.execute("CREATE TABLE zbig (id INTEGER PRIMARY KEY, label TEXT)")
  400.times { |n| db.execute("INSERT INTO zbig VALUES (#{n + 1}, 'row #{n + 1}')") }
end

# A second database, so opening a file while one is already open has to make a
# second window, and so the switcher's menu has to be rebuilt.
OTHER_DB = File.join(SCRATCH, "other.db")
SQLite3::Database.new(OTHER_DB) do |db|
  db.execute("CREATE TABLE widgets (id INTEGER PRIMARY KEY, label TEXT)")
  db.execute("INSERT INTO widgets VALUES (1, 'only')")
end

# A database with no tables at all, which is the "Table list empty" state.
EMPTY_DB = File.join(SCRATCH, "empty.db")
SQLite3::Database.new(EMPTY_DB) { |db| db.execute("PRAGMA user_version = 1") }

# Not a database, which is the "File is not a SQLite database" state.
NOT_A_DB = File.join(SCRATCH, "notes.txt")
File.write(NOT_A_DB, "this is plain text, not a SQLite file\n")

def gfile(path) = Gio::File.new_for_path(path)

# --- Widget helpers ---------------------------------------------------------

# Every descendant of `widget`, depth first. The ColumnView builds its cell
# widgets itself, so the only way to see what Item wrote into them is to walk
# the tree it made.
# A nested ColumnView is collected but not walked into. GTK builds, recycles
# and destroys that view's row and cell widgets itself, and walking a four
# hundred row one while it is doing that segfaults the process: the walk holds
# a Ruby proxy for a row widget GTK has just thrown away. Nothing below a
# ColumnView is part of the layout anyway, and a walk that wants the cells
# starts at the ColumnView itself, which is still walked in full.
def descendants(widget, found = [])
  child = widget.first_child
  while child
    found << child
    unless child.is_a?(Gtk::ColumnView)
      descendants(child, found)
    end
    child = child.next_sibling
  end
  found
end

def labels_in(widget) = descendants(widget).grep(Gtk::Label)

# A value cell carries its column index as its widget name, which is how the
# context-menu gesture finds it; the same name is how this script finds one.
def value_cells(column_view, column_index)
  labels_in(column_view).select { |label| label.name == column_index.to_s }
end

def accel_equal?(left, right)
  Array(left).map { |accel| Gtk.accelerator_parse(accel) } ==
    Array(right).map { |accel| Gtk.accelerator_parse(accel) }
end

def menu_items(model)
  (0...model.n_items).map do |index|
    [
      model.get_item_attribute_value(index, "label", nil),
      model.get_item_attribute_value(index, "action", nil),
      model.get_item_attribute_value(index, "target", nil),
    ]
  end
end

# A GFileInfo is what a GtkFileFilter matches against; the content type is set
# because GIO logs a critical when a filter asks an info that has none.
def file_info(name)
  Gio::FileInfo.new.tap do |info|
    info.display_name = name
    info.content_type = "application/octet-stream"
  end
end

def capture_stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = STDOUT
end

def capture_stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  $stderr = STDERR
end

# What the clipboard holds, read back through GDK rather than trusted. The read
# is asynchronous, so the step that asks is never the step that checks.
CLIPBOARD = {}

# Adwaita::ToastOverlay hands nothing back once a toast is added, and the
# toast widget it builds carries the title but not the timeout. So the
# window's overlay is watched: add_toast records the Adwaita::Toast it was
# given and then shows it exactly as before. This is the only way to see a
# toast's timeout from the outside.
TOASTS = []

module ToastSpy
  def add_toast(toast)
    TOASTS << toast
    super
  end
end

def watch_toasts(overlay)
  overlay.tap do |o|
    unless o.singleton_class.include?(ToastSpy)
      o.singleton_class.prepend(ToastSpy)
    end
  end
end

# The toast widgets libadwaita has built inside the overlay, youngest last.
# `class.name` is nil for these: ruby-gnome builds an anonymous Ruby class for
# a GType it has no binding for, and AdwToastWidget is private to libadwaita.
# The class still prints its GType name, so that is what is matched.
def toast_widgets(overlay)
  descendants(overlay).select { |widget| widget.class.to_s == "AdwToastWidget" }
end

# What each of those toasts says. The title is markup, so the label's own
# markup string is read rather than the text GTK renders from it — that is
# what makes the bytes comparable with upstream's format string.
def toast_titles(overlay)
  toast_widgets(overlay).map do |widget|
    descendants(widget).grep(Gtk::Label).first&.label
  end
end

# Turns the main loop until the block answers true, or until `limit` turns
# have gone by. A step runs between two ticks of the driver's timeout, and
# GTK does its laying out in the frame cycle, so something that needs more
# than one frame — four hundred rows being measured, for instance — is not
# ready when the next step looks at it. Asking for turns rather than sleeping
# for a guessed interval keeps the wait as short as the work.
def settle_until(limit = 120)
  turns = 0

  until yield || turns >= limit
    GLib::MainContext.default.iteration(true)
    turns += 1
  end

  turns
end

def read_clipboard(key)
  CLIPBOARD.delete(key)
  Gdk::Display.default.clipboard.read_text_async(nil) do |clipboard, result|
    CLIPBOARD[key] = clipboard.read_text_finish(result)
  rescue StandardError => e
    CLIPBOARD[key] = "clipboard read failed: #{e.class}: #{e.message}"
  end
end

# --- The run ----------------------------------------------------------------

APP = Bobby::Application.new

GtkDriver.drive(APP, shots: SHOTS) do |d, app|
  d.window { app.windows.first&.window }

  # -- The application and its empty window --------------------------------

  d.step("the application built and activate made one empty window") do
    d.check("the application is a Gtk::Application") { app.app.is_a?(Gtk::Application) }
    d.check("its id is upstream's app id") { app.app.application_id == Bobby::App::ID }
    d.check("it handles open, so a file argument is not an activate") do
      app.app.flags.to_i & Gio::ApplicationFlags::HANDLES_OPEN.to_i != 0
    end
    d.check("activate made exactly one window") { app.windows.length == 1 }
    d.check("it is the only toplevel") { Gtk::Window.list_toplevels.length == 1 }
    app.windows.first.then do |window|
      d.check("the window is a Gtk::ApplicationWindow") do
        window.window.is_a?(Gtk::ApplicationWindow)
      end
      d.check("it is the application's active window") do
        app.app.active_window == window.window
      end
      d.check("it is realised and mapped, with a size") do
        window.window.realized? && window.window.mapped? &&
          window.window.width.positive? && window.window.height.positive?
      end
      d.check("the GTK titlebar row is taken away") { !window.empty_titlebar.visible? }
      d.check("it reports itself empty") { window.empty? }
      d.check("so it has no key for the application to index it by") { window.key.nil? }
      d.check("and no database") { window.database.nil? }
      d.check("its title is Bobby") { window.window.title == Bobby::Window::EMPTY_TITLE }
    end
  end

  d.step("the empty state is the Browse Databases status page") do
    app.windows.first.then do |window|
      d.check("the status page is the toolbar view's content") do
        window.toolbar_view.content.equal?(window.empty_page)
      end
      d.check("the header bar is flat with nothing to read") do
        window.toolbar_view.top_bar_style == :flat
      end
      d.check("its icon is the app's symbolic icon") do
        window.empty_page.icon_name == Bobby::Window::EMPTY_ICON
      end
      d.check("its heading is upstream's") do
        window.empty_page.title == Bobby::Window::EMPTY_HEADING
      end
      d.check("its description names drag and drop") do
        window.empty_page.description == Bobby::Window::EMPTY_DESCRIPTION
      end
      d.check("the open pill is the page's child") do
        window.empty_page.child.equal?(window.empty_button.button)
      end
      d.check("the pill is labelled Open...") do
        window.empty_button.button.label == Bobby::Widgets::OpenButton::LABEL
      end
      d.check("it carries the pill and suggested-action classes") do
        window.empty_button.button.has_css_class?("pill") &&
          window.empty_button.button.has_css_class?("suggested-action")
      end
      d.check("it routes to app.open rather than its own handler") do
        window.empty_button.button.action_name == "app.open"
      end
      d.check("and GTK found that action, so the pill is sensitive") do
        window.empty_button.button.sensitive?
      end
    end
    d.shot("01-empty")
  end

  d.step("a window asks for upstream's 960x640 before it is presented") do
    Bobby::Window.new(app.app, opener: APP).then do |fresh|
      d.check("the geometry is upstream's") do
        fresh.window.default_size == [960, 640]
      end
      d.check("and those are the constants the port carries") do
        [Bobby::Window::DEFAULT_WIDTH, Bobby::Window::DEFAULT_HEIGHT] == [960, 640]
      end
      fresh.build
      d.check("building it leaves the geometry alone") do
        fresh.window.default_size == [960, 640]
      end
      d.check("and puts the toolbar view in it") do
        fresh.window.child.equal?(fresh.toolbar_view)
      end
      d.check("flat is on the window itself, as upstream sets it") do
        fresh.window.has_css_class?("flat")
      end
      d.check("it starts in the empty state") { fresh.empty? }
      fresh.window.destroy
      d.check("destroying it leaves the drive's own window alone") do
        app.windows.length == 1
      end
    end
  end

  # -- Actions and accelerators ---------------------------------------------

  d.step("the five app actions are registered with upstream's accelerators") do
    {
      "about"       => nil,
      "open"        => Bobby::Actions::AppOpen::ACCELS,
      "preferences" => Bobby::Actions::AppPreferences::ACCELS,
      "quit"        => Bobby::Actions::AppQuit::ACCELS,
      "shortcuts"   => Bobby::Actions::AppShortcuts::ACCELS,
    }.each do |name, accels|
      d.check("app.#{name} is an action on the application") do
        app.app.lookup_action(name).is_a?(Gio::SimpleAction)
      end
      d.check("app.#{name} is enabled") { app.app.lookup_action(name).enabled? }
      if accels.nil?
        d.check("app.#{name} has no accelerator, as upstream has none") do
          app.app.get_accels_for_action("app.#{name}").empty?
        end
      else
        d.check("app.#{name} is #{accels.first}") do
          accel_equal?(app.app.get_accels_for_action("app.#{name}"), accels)
        end
      end
    end
    d.check("app.open-menu is F10, the menu button's keyboard route") do
      accel_equal?(
        app.app.get_accels_for_action("app.#{Bobby::Widgets::Menu::ACTION}"),
        Bobby::Widgets::Menu::ACCELS,
      )
    end
    d.check("win.close is Ctrl+W") do
      accel_equal?(app.app.get_accels_for_action("win.close"), Bobby::Actions::WinClose::ACCELS)
    end
    d.check("win.close is an action on the window") do
      app.windows.first.window.lookup_action("close").is_a?(Gio::SimpleAction)
    end
  end

  d.step("the header bar's menu button carries upstream's three items") do
    app.windows.first.main_menu.then do |menu|
      d.check("it is a Gtk::MenuButton") { menu.button.is_a?(Gtk::MenuButton) }
      d.check("it is packed into the header bar") do
        descendants(app.windows.first.header_bar).include?(menu.button)
      end
      d.check("its icon is the hamburger") { menu.button.icon_name == "open-menu-symbolic" }
      d.check("its tooltip is Main Menu") { menu.button.tooltip_text == "Main Menu" }
      d.check("its model is a Gio::Menu") { menu.menu.is_a?(Gio::Menu) }
      d.check("it carries three items") { menu.menu.n_items == 3 }
      d.check("their labels and actions are upstream's, in order") do
        menu_items(menu.menu).map { |label, action, _| [label, action] } ==
          Bobby::Widgets::Menu::ITEMS.to_a
      end
      d.check("every one of them names an action that exists") do
        Bobby::Widgets::Menu::ITEMS.values.all? do |action|
          app.app.lookup_action(action.delete_prefix("app.")).is_a?(Gio::SimpleAction)
        end
      end
      d.check("the popover is not showing yet") { !menu.button.active? }
      menu.open_menu_action.activate(nil)
    end
  end

  d.step("F10's action popped the menu open") do
    app.windows.first.main_menu.then do |menu|
      # Popping a menu up is animated, so the button's active state arrives in
      # the frame cycle rather than on the next tick of the driver's timeout.
      settle_until(40) { menu.button.active? }
      d.check("the menu button is active now") { menu.button.active? }
      d.check("its popover is a Gtk::PopoverMenu built from the model") do
        menu.button.popover.is_a?(Gtk::PopoverMenu)
      end
      # The popover is a surface of its own, not part of the window's picture,
      # so it is what gets shot.
      d.shot("02-main-menu", menu.button.popover)
      menu.button.active = false
    end
  end

  # -- The icons the app names ----------------------------------------------

  d.step("every icon the app names resolves in the theme") do
    d.check("the shipped icons directory is where Icons looks") do
      File.directory?(Bobby::Icons::DIR)
    end
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      d.check("the search path carries the shipped directory") do
        theme.search_path.include?(Bobby::Icons::DIR)
      end
      [
        Bobby::App::ID,
        "#{Bobby::App::ID}-symbolic",
        Bobby::Window::ERROR_ICON,
        "open-menu-symbolic",
      ].each do |name|
        d.check("the icon theme resolves #{name}") { theme.has_icon?(name) }
      end
    end
    d.check("installing twice is harmless") do
      Bobby::Icons.install
      Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?(Bobby::App::ID)
    end
  end

  # -- The settings schema ---------------------------------------------------

  d.step("the GSettings schema is the one upstream ships, with its defaults") do
    Bobby::Settings.instance.then do |settings|
      d.check("the schema dir points at the checkout's data/") do
        ENV["GSETTINGS_SCHEMA_DIR"] == Bobby::Settings::SCHEMA_DIR
      end
      d.check("the schema resolves") { settings.gio.is_a?(Gio::Settings) }
      d.check("row-numbers defaults to true") { settings.row_numbers? }
      d.check("monospace-font defaults to false") { !settings.monospace_font? }
      d.check("row-order defaults to newest first") do
        settings.row_order == Bobby::Sqlite::RowOrder::DESCENDING
      end
      d.check("column-separator defaults to tabs") do
        settings.column_separator == Bobby::Sqlite::ColumnSeparator::TABS
      end
      d.check("all four of upstream's keys are in the schema") do
        Bobby::Settings::KEYS.all? { |key| settings.gio.settings_schema.has_key?(key) }
      end
      d.check("and the schema is upstream's own id") do
        settings.gio.settings_schema.id == Bobby::Settings::SCHEMA_ID
      end
      d.check("a key upstream does not declare is not in it") do
        !settings.gio.settings_schema.has_key?("row-colours")
      end
      d.check("row-order's choices are the schema's, in order") do
        settings.choices(Bobby::Settings::ROW_ORDER) == ["newest-first", "oldest-first"]
      end
      d.check("column-separator's choices are the schema's, in order") do
        settings.choices(Bobby::Settings::COLUMN_SEPARATOR) ==
          %w[tabs spaces commas markdown]
      end
      d.check("a position resolves to a value") do
        settings.value_at(Bobby::Settings::COLUMN_SEPARATOR, 3) == "markdown"
      end
      d.check("and a value back to its position") do
        settings.index_of(Bobby::Settings::COLUMN_SEPARATOR, "commas") == 2
      end
      d.check("the stored value's position is what the combo rows take") do
        settings.selected_index(Bobby::Settings::ROW_ORDER).zero?
      end
      d.check("an unknown key has no choices rather than raising") do
        settings.choices("nonexistent-key").empty?
      end
    end
  end

  # -- The SQLite layer ------------------------------------------------------

  d.step("a table name is validated before it can reach a query") do
    d.check("a plain name parses") { Bobby::Sqlite::TableName.parse("people").to_s == "people" }
    d.check("underscores and digits are allowed") do
      Bobby::Sqlite::TableName.parse("audit_log_2").to_s == "audit_log_2"
    end
    d.check("an empty name is refused") { Bobby::Sqlite::TableName.parse("").nil? }
    d.check("SQLite's own tables are refused") do
      Bobby::Sqlite::TableName.parse("sqlite_master").nil?
    end
    d.check("a name with a quote in it is refused") do
      Bobby::Sqlite::TableName.parse("people\"; DROP TABLE people; --").nil?
    end
    d.check("a name with a space in it is refused") do
      Bobby::Sqlite::TableName.parse("my table").nil?
    end
    d.check("the default is upstream's") do
      Bobby::Sqlite::TableName.new.to_s == Bobby::Sqlite::TableName::DEFAULT
    end
    d.check("two names with the same text are equal") do
      Bobby::Sqlite::TableName.parse("a") == Bobby::Sqlite::TableName.parse("a")
    end
  end

  d.step("affinity reads a declared type the way the SQLite docs describe") do
    {
      "INTEGER"      => Bobby::Sqlite::Affinity::INTEGER,
      "BIGINT"       => Bobby::Sqlite::Affinity::INTEGER,
      "VARCHAR(255)" => Bobby::Sqlite::Affinity::TEXT,
      "CLOB"         => Bobby::Sqlite::Affinity::TEXT,
      "BLOB"         => Bobby::Sqlite::Affinity::BLOB,
      ""             => Bobby::Sqlite::Affinity::BLOB,
      "DOUBLE"       => Bobby::Sqlite::Affinity::REAL,
      "FLOAT"        => Bobby::Sqlite::Affinity::REAL,
      "DECIMAL(5,2)" => Bobby::Sqlite::Affinity::NUMERIC,
    }.each do |declaration, type|
      d.check("#{declaration.inspect} is #{type}") do
        Bobby::Sqlite::Affinity.parse(declaration).type == type
      end
    end
    d.check("a declared-but-unread column shows ???") do
      Bobby::Sqlite::Affinity.parse("TEXT").to_s == Bobby::Sqlite::Affinity::UNKNOWN
    end
  end

  d.step("affinity wraps a value the way rusqlite's ValueRef does") do
    d.check("nil is NULL and shows an em dash") do
      Bobby::Sqlite::Affinity.from_value(nil).then do |affinity|
        affinity.type == Bobby::Sqlite::Affinity::NULL &&
          affinity.to_s == Bobby::Sqlite::Affinity::EM_DASH &&
          affinity.tooltip == "NULL" &&
          affinity.dimmed?
      end
    end
    d.check("an integer keeps its value and is not dimmed") do
      Bobby::Sqlite::Affinity.from_value(42).then do |affinity|
        affinity.type == Bobby::Sqlite::Affinity::INTEGER &&
          affinity.to_s == "42" &&
          affinity.tooltip == "INTEGER 42" &&
          !affinity.dimmed?
      end
    end
    d.check("a float is REAL") do
      Bobby::Sqlite::Affinity.from_value(1.5).type == Bobby::Sqlite::Affinity::REAL
    end
    d.check("a UTF-8 string is TEXT") do
      Bobby::Sqlite::Affinity.from_value("hi").then do |affinity|
        affinity.type == Bobby::Sqlite::Affinity::TEXT && affinity.to_s == "hi"
      end
    end
    d.check("a binary string is a blob, shown as a byte count") do
      Bobby::Sqlite::Affinity.from_value("\xDE\xAD\xBE\xEF".b).then do |affinity|
        affinity.type == Bobby::Sqlite::Affinity::BLOB &&
          affinity.to_s == "4 BYTES" &&
          affinity.dimmed?
      end
    end
    d.check("its tooltip is a hex preview") do
      Bobby::Sqlite::Affinity.from_value("\xDE\xAD\xBE\xEF".b).tooltip == "BLOB DE AD BE EF …"
    end
    d.check("the preview stops at eight bytes") do
      Bobby::Sqlite::Affinity.hex_preview((1..16).to_a.pack("C*"), 8).split.length == 8
    end
    d.check("invalid UTF-8 in a text column is scrubbed, not raised on") do
      "caf\xC3".dup.force_encoding(Encoding::UTF_8).then do |broken|
        Bobby::Sqlite::Affinity.from_value(broken).to_s.valid_encoding?
      end
    end
    d.check("an unparsable numeric shows an em dash") do
      Bobby::Sqlite::Affinity.new(type: Bobby::Sqlite::Affinity::NUMERIC).then do |affinity|
        affinity.to_s == Bobby::Sqlite::Affinity::EM_DASH && affinity.dimmed?
      end
    end
    d.check("type_string is the upper-cased name") do
      Bobby::Sqlite::Affinity.from_value(1).type_string == "INTEGER"
    end
    d.check("two affinities over the same value are equal") do
      Bobby::Sqlite::Affinity.from_value(1) == Bobby::Sqlite::Affinity.from_value(1) &&
        Bobby::Sqlite::Affinity.from_value(1).hash ==
          Bobby::Sqlite::Affinity.from_value(1).hash
    end
  end

  d.step("the column separators and the markdown row format are upstream's") do
    Bobby::Sqlite::ColumnSeparator.then do |separator|
      d.check("the GSettings value parses") { separator.parse("commas") == separator::COMMAS }
      d.check("so does the character itself") { separator.parse("\t") == separator::TABS }
      d.check("an unknown value is nil, not a default") { separator.parse("pipes").nil? }
      d.check("markdown has no single character") { separator.character(separator::MARKDOWN).nil? }
      d.check("the default is tabs") { separator::DEFAULT == separator::TABS }
    end
    Bobby::Sqlite::Row.new(
      [1, "a", nil].map { |value| Bobby::Sqlite::Affinity.from_value(value) },
    ).then do |row|
      d.check("tabs join the cells") do
        row.format_with(Bobby::Sqlite::ColumnSeparator::TABS) ==
          "1\ta\t#{Bobby::Sqlite::Affinity::EM_DASH}"
      end
      d.check("commas join them too") do
        row.format_with(Bobby::Sqlite::ColumnSeparator::COMMAS).include?("1,a,")
      end
      d.check("markdown wraps the whole row in pipes") do
        row.format_with(Bobby::Sqlite::ColumnSeparator::MARKDOWN) ==
          "| 1 | a | #{Bobby::Sqlite::Affinity::EM_DASH} |"
      end
      d.check("an unknown separator falls back to tabs") do
        row.format_with(nil) == row.format_with(Bobby::Sqlite::ColumnSeparator::TABS)
      end
      d.check("a cell past the end is nil") { row.cell(99).nil? }
    end
    d.check("newest-first is DESC") do
      Bobby::Sqlite::RowOrder.keyword(Bobby::Sqlite::RowOrder::DESCENDING) == "DESC"
    end
    d.check("oldest-first is ASC") do
      Bobby::Sqlite::RowOrder.keyword(Bobby::Sqlite::RowOrder::ASCENDING) == "ASC"
    end
    d.check("nil falls back to the default, DESC") do
      Bobby::Sqlite::RowOrder.keyword(nil) == "DESC"
    end
    d.check("an unknown GSettings value is nil") do
      Bobby::Sqlite::RowOrder.from_settings("sideways").nil?
    end
  end

  d.step("a database opens read-only and immutable, and refuses what is not one") do
    Bobby::Sqlite::Database.from_file(gfile(MAIN_DB)).then do |database|
      d.check("the uri carries immutable=1") do
        database.uri.end_with?("?#{Bobby::Sqlite::Database::IMMUTABLE_QUERY}")
      end
      d.check("it is open") { !database.connection.closed? }
      d.check("it reports its path") { database.path == MAIN_DB }
      d.check("it refuses a write, because query_only is set") do
        begin
          database.connection.execute("CREATE TABLE nope (a)")
          false
        rescue SQLite3::Exception
          true
        end
      end
      d.check("data_version reads the pragma upstream watches") do
        database.data_version.is_a?(Integer)
      end
      d.check("the tables and views come back in name order") do
        database.tables.map { |table| table.name.to_s } ==
          ["audit_log", "people", "people_view", "zbig"]
      end
      d.check("has_row_id is three-valued, as upstream's is") do
        database.tables.map(&:has_row_id) == [false, true, nil, true]
      end
      d.check("only an ordinary table can be read in rowid order") do
        database.tables.map(&:row_id?) == [false, true, false, true]
      end
      d.check("the view says it is one") do
        database.tables.map(&:view?) == [false, false, true, false]
      end
      database.tables.find { |table| table.name.to_s == "people" }.then do |people|
        d.check("row_count counts the rows") { database.row_count(people) == 3 }
        d.check("the columns come back with their declared affinities") do
          database.columns(people).map { |column| [column.name, column.affinity.type] } == [
            ["id", Bobby::Sqlite::Affinity::INTEGER],
            ["name", Bobby::Sqlite::Affinity::TEXT],
            ["score", Bobby::Sqlite::Affinity::REAL],
            ["data", Bobby::Sqlite::Affinity::BLOB],
            ["note", Bobby::Sqlite::Affinity::TEXT],
            ["rating", Bobby::Sqlite::Affinity::NUMERIC],
          ]
        end
        d.check("the primary key is marked, and only it") do
          database.columns(people).map(&:primary_key?) == [true, false, false, false, false, false]
        end
        d.check("unique is false everywhere, as it is upstream") do
          database.columns(people).none?(&:unique)
        end
        d.check("newest first is what the default order reads") do
          database.rows(people).first.cell(0).value == 3
        end
        d.check("every row has a cell per column") do
          database.rows(people).all? { |row| row.cells.length == 6 }
        end
        d.check("the blob in row 1 is read as a blob") do
          database.rows(people).last.cell(3).type == Bobby::Sqlite::Affinity::BLOB
        end
        d.check("the NULL in row 2 is read as NULL") do
          database.rows(people).find { |row| row.cell(0).value == 2 }.cell(3).type ==
            Bobby::Sqlite::Affinity::NULL
        end
        d.check("a limit is honoured") { database.rows(people, limit: 2).length == 2 }
      end
      d.check("the reserved index column has no name and no key") do
        Bobby::Sqlite::Column.index.then do |column|
          column.name == "" && !column.primary_key? && !column.not_null?
        end
      end
      database.close
      d.check("close closes the connection") { database.connection.closed? }
      d.check("closing twice is harmless") do
        database.close
        database.connection.closed?
      end
    end
    Bobby::Sqlite::Database.from_file(gfile(MAIN_DB), Bobby::Sqlite::RowOrder::ASCENDING)
      .then do |ascending|
        d.check("oldest first reverses the rows") do
          ascending.rows(ascending.tables.find { |t| t.name.to_s == "people" })
            .first.cell(0).value == 1
        end
        ascending.close
      end
    d.check("a file that is not a database raises upstream's message") do
      begin
        Bobby::Sqlite::Database.from_file(gfile(NOT_A_DB))
        false
      rescue Bobby::Sqlite::Database::Error => e
        e.message == Bobby::Sqlite::Database::NOT_A_DATABASE
      end
    end
    d.check("a file that is not there raises too") do
      begin
        Bobby::Sqlite::Database.from_file(gfile(File.join(SCRATCH, "missing.db")))
        false
      rescue Bobby::Sqlite::Database::Error
        true
      end
    end
  end

  d.step("the cache's list model carries one RowObject per row") do
    Bobby::Sqlite::Database.from_file(gfile(MAIN_DB)).then do |database|
      database.tables.find { |table| table.name.to_s == "people" }.then do |people|
        Bobby::Sqlite::Cache.new(database, people).then do |cache|
          d.check("it counts the rows") { cache.row_count == 3 }
          d.check("the model is a Gio::ListModel") { cache.model.is_a?(Gio::ListModel) }
          d.check("with one item per row") { cache.model.n_items == 3 }
          d.check("each item is a RowObject holding a Row") do
            cache.model.get_item(0).then do |item|
              item.is_a?(Bobby::Sqlite::RowObject) && item.row.is_a?(Bobby::Sqlite::Row)
            end
          end
          d.check("past the end is nil, not a raise") { cache.model.get_item(99).nil? }
          d.check("the model's items are the RowObjects the cache holds") do
            (0...cache.model.n_items).all? do |index|
              cache.model.get_item(index).equal?(cache.row_objects[index])
            end
          end
          # The bug this is here for: the Ruby half of a RowObject is collected
          # as soon as nothing on the Ruby side refers to it, and what comes
          # back then is a new RowObject with no Row in it.
          d.check("and they keep their rows across a garbage collection") do
            3.times { GC.start(full_mark: true, immediate_sweep: true) }
            (0...cache.model.n_items).none? { |index| cache.model.get_item(index).row.nil? }
          end
        end
      end
      database.close
    end
  end

  # -- The error state ------------------------------------------------------

  d.step("a file that is not a database is opened into the error state") do
    APP.handle_open(gfile(NOT_A_DB))
  end

  d.step("the error page names the file and the reason") do
    app.windows.first.then do |window|
      d.check("the window is in its error state") { window.state == :error }
      d.check("it is no longer empty") { !window.empty? }
      d.check("it keyed itself by the file it failed on") { window.key == NOT_A_DB }
      d.check("it holds no database") { window.database.nil? }
      d.check("the error page is the content") do
        window.toolbar_view.content.equal?(window.error_page)
      end
      d.check("its icon is dialog-error-symbolic") do
        window.error_page.icon_name == Bobby::Window::ERROR_ICON
      end
      d.check("its heading is Unable to Open File") do
        window.error_page.title == Bobby::Window::ERROR_HEADING
      end
      d.check("its description is the database layer's own message") do
        window.error_page.description == Bobby::Sqlite::Database::NOT_A_DATABASE
      end
      d.check("it offers the same open pill") do
        window.error_page.child.equal?(window.error_button.button)
      end
      d.check("the title is the file's basename") { window.window.title == "notes.txt" }
      d.check("no second window was made for it") { app.windows.length == 1 }
    end
    d.shot("03-error")
  end

  # Only an empty window is reused — upstream looks for the one whose widget
  # name is IS_EMPTY_WINDOW, and an error window's name is the path it failed
  # on — so a second file while this one is showing an error makes a second
  # window, and a database with no tables in it lands there.
  d.step("a database with no tables makes its own window and says so") do
    APP.handle_open(gfile(EMPTY_DB))
  end

  d.step("the second window says Table list empty, and the first is untouched") do
    d.check("an error window was not reused, so there are two windows") do
      app.windows.length == 2
    end
    app.windows.last.then do |window|
      d.check("the new one is in its error state") { window.state == :error }
      d.check("its description is upstream's Table list empty") do
        window.error_page.description == Bobby::Window::NO_TABLES
      end
      d.check("it keyed itself by the empty database") { window.key == EMPTY_DB }
      d.shot("04-no-tables", window.window)
      window.close
    end
    d.check("the first window still shows the file it failed on") do
      app.windows.first.error_page.description == Bobby::Sqlite::Database::NOT_A_DATABASE
    end
  end

  d.step("asking for a table that is not in the file says so too") do
    d.check("the second window closed and left the list") { app.windows.length == 1 }
    app.windows.first.then do |window|
      window.show_empty_state
      d.check("the window is empty again, so it is the one a file goes into") do
        window.empty?
      end
    end
    APP.handle_open(gfile(MAIN_DB), table_name: "nosuchtable")
  end

  d.step("the reason is Table does not exist, not Table list empty") do
    d.check("the empty window took the file rather than a new one") do
      app.windows.length == 1
    end
    app.windows.first.then do |window|
      d.check("the window is in its error state") { window.state == :error }
      d.check("the description is upstream's Table does not exist") do
        window.error_page.description == Bobby::Window::NO_SUCH_TABLE
      end
    end
  end

  # -- The content state ----------------------------------------------------

  d.step("the real database opens into the content state") do
    app.windows.first.show_empty_state
    APP.handle_open(gfile(MAIN_DB))
  end

  d.step("the window swapped to the table, and the header bar raised its border") do
    app.windows.first.then do |window|
      d.check("the window is in its content state") { window.state == :content }
      d.check("it keyed itself by the file's path") { window.key == MAIN_DB }
      d.check("it holds the open database") { window.database.is_a?(Bobby::Sqlite::Database) }
      d.check("the toast overlay is the content") do
        window.toolbar_view.content.equal?(window.overlay)
      end
      d.check("the overlay holds the layout box") { window.overlay.child.equal?(window.layout) }
      d.check("the banner is the layout's first child") do
        window.layout.first_child.equal?(window.banner)
      end
      d.check("the banner is not revealed, as upstream's never is") do
        !window.banner.revealed?
      end
      d.check("its button says Reload and points at win.reload") do
        window.banner.button_label == Bobby::Window::BANNER_BUTTON &&
          window.banner.action_name == "win.reload"
      end
      d.check("the table's scroller is in the layout") do
        descendants(window.layout).include?(window.content.column_view)
      end
      d.check("the header bar took the raised border") do
        window.toolbar_view.top_bar_style == :raised_border
      end
      d.check("the title is the database's basename") do
        window.window.title == "fixture.db"
      end
      d.check("the first table in name order is the one showing") do
        window.content.table.name.to_s == "audit_log"
      end
      d.check("and the window's index agrees") { window.table_index.zero? }
      d.check("the four content actions are on the window now") do
        ["copy-row", "copy-val", "reload", "table"].all? do |name|
          window.window.lookup_action(name).is_a?(Gio::SimpleAction)
        end
      end
      d.check("win.copy-row is Ctrl+C") do
        accel_equal?(
          app.app.get_accels_for_action("win.copy-row"),
          Bobby::Actions::WinCopyRow::ACCELS,
        )
      end
      d.check("win.reload is Ctrl+R") do
        accel_equal?(
          app.app.get_accels_for_action("win.reload"),
          Bobby::Actions::WinReload::ACCELS,
        )
      end
      d.check("win.table's state is the open table's index") do
        window.switch_table_action.action.state.to_s == "0"
      end
    end
  end

  d.step("the switcher is in the header bar, split into Views and Tables") do
    app.windows.first.then do |window|
      window.switcher.then do |switcher|
        d.check("the button is packed into the header bar") do
          descendants(window.header_bar).include?(switcher.button)
        end
        d.check("it is labelled with the open table") { switcher.label == "audit_log" }
        d.check("its tooltip is Tables") do
          switcher.button.tooltip_text == Bobby::Widgets::Switcher::TOOLTIP
        end
        d.check("the menu has a Views section and a Tables section") do
          switcher.menu.n_items == 2
        end
        d.check("the section labels count what is in them") do
          menu_items(switcher.menu).map(&:first) == ["Views – 1", "Tables – 3"]
        end
        d.check("the view is in the Views section, with its underscore doubled") do
          menu_items(switcher.view_section).map { |label, action, _| [label, action] } ==
            [["people__view", "win.table"]]
        end
        d.check("the three tables are in the Tables section") do
          menu_items(switcher.table_section).map(&:first) ==
            ["audit__log", "people", "zbig"]
        end
        d.check("the underscore is doubled so GMenu does not eat it") do
          menu_items(switcher.table_section).first.first == "audit__log"
        end
        d.check("each item targets its index in the full table list") do
          menu_items(switcher.table_section).map(&:last) == ["0", "1", "3"] &&
            menu_items(switcher.view_section).map(&:last) == ["2"]
        end
      end
    end
    d.shot("05-content")
  end

  d.step("the table renders the cells Item wrote") do
    app.windows.first.content.then do |content|
      d.check("there is one view column per table column plus the index one") do
        content.view_columns.length == content.columns.length &&
          content.columns.length == 3
      end
      d.check("the index column is first and not resizable") do
        content.index_column.equal?(content.view_columns.first) &&
          !content.index_column.resizable?
      end
      d.check("the index column is visible, as row-numbers is on") do
        content.index_column.visible?
      end
      d.check("the last column expands") { content.view_columns.last.expand? }
      d.check("the primary key's header carries the diamond") do
        content.view_columns[1].title == "key #{Bobby::Widgets::Item::SYMBOL_KEY}"
      end
      d.check("a plain column's header is just its name") do
        content.view_columns[2].title == "msg"
      end
      d.check("each view column's id is its index") do
        content.view_columns.map(&:id) == ["0", "1", "2"]
      end
      d.check("the model holds both rows") { content.model.n_items == 2 }
      d.check("the content holds the cache that owns them") do
        content.model.get_item(0).equal?(content.cache.row_objects.first)
      end
      d.check("so every row in the model still has its Row behind it") do
        (0...content.model.n_items).all? { |index| !content.row_at(index).nil? }
      end
      d.check("the first row is selected to begin with") { content.selected_position.zero? }
      d.check("row_at reads the Row behind a position") do
        content.row_at(0).is_a?(Bobby::Sqlite::Row)
      end
      d.check("selected_row is the same one") do
        content.selected_row.cells.map(&:to_s) == content.row_at(0).cells.map(&:to_s)
      end
      d.check("a position past the end is nil") { content.row_at(99).nil? }
      labels_in(content.column_view).then do |found|
        d.check("the index cells are numbered from one") do
          found.any? { |label| label.text == "1" } && found.any? { |label| label.text == "2" }
        end
        d.check("the value cells hold the table's own values") do
          found.map(&:text).then do |texts|
            texts.include?("k1") && texts.include?("first message")
          end
        end
        d.check("a value cell's widget name is its column index") do
          value_cells(content.column_view, 1).any? { |label| label.text == "k1" }
        end
        d.check("the index cell's tooltip is n of the total") do
          found.find { |label| label.text == "1" && label.has_css_class?("dimmed") }
            .then { |label| label&.parent&.tooltip_text == "1 / 2" }
        end
        d.check("a primary-key cell's tooltip is prefixed with the key marker") do
          value_cells(content.column_view, 1).find { |label| label.text == "k1" }
            .then { |label| label.parent.tooltip_text.start_with?(Bobby::Widgets::Item::SYMBOL_KEY) }
        end
        d.check("an ordinary cell's tooltip is its affinity and value") do
          value_cells(content.column_view, 2).find { |label| label.text == "first message" }
            .then { |label| label.parent.tooltip_text == "TEXT first message" }
        end
        d.check("the index cells are dimmed and monospace") do
          found.find { |label| label.text == "1" }.then do |label|
            label.has_css_class?("dimmed") && label.has_css_class?("monospace")
          end
        end
        d.check("the value cells are numeric and not monospace by default") do
          value_cells(content.column_view, 1).first.then do |label|
            label.has_css_class?("numeric") && !label.has_css_class?("monospace")
          end
        end
      end
    end
  end

  # -- The context menu -----------------------------------------------------

  d.step("right-clicking a cell opens the copy menu over it") do
    app.windows.first.content.then do |content|
      value_cells(content.column_view, 2).first.then do |label|
        label.translate_coordinates(content.column_view, 4, 4).then do |coordinates|
          d.check("the cell has a position in the column view") { !coordinates.nil? }
          d.check("the pick under that position is the cell's label") do
            content.column_view.pick(
              coordinates.first,
              coordinates.last,
              Gtk::PickFlags::NON_TARGETABLE,
            ).equal?(label)
          end
          content.click_gesture.signal_emit(
            "pressed",
            1,
            coordinates.first.to_f,
            coordinates.last.to_f,
          )
        end
      end
    end
  end

  d.step("the menu is a popover with Copy and Copy Row in it") do
    app.windows.first.content.then do |content|
      descendants(content.column_view).grep(Gtk::PopoverMenu).then do |popovers|
        d.check("a popover menu was parented to the column view") { popovers.length == 1 }
        d.check("it has no arrow, as upstream's has none") { !popovers.first.has_arrow? }
        d.check("it is showing") { popovers.first.visible? }
        popovers.first.menu_model.then do |model|
          d.check("it has two items") { model.n_items == 2 }
          d.check("the first is Copy, targeting the cell that was clicked") do
            menu_items(model).first == ["Copy", "win.copy-val", "0:1"]
          end
          d.check("the second is Copy Row") do
            menu_items(model).last.first(2) == ["Copy Row", "win.copy-row"]
          end
        end
        d.shot("06-context-menu", popovers.first)
        popovers.first.popdown
      end
    end
  end

  # -- The clipboard actions ------------------------------------------------

  d.step("win.copy-val copies the cell the menu named") do
    app.windows.first.window.activate_action("copy-val", GLib::Variant.new("0:1"))
    read_clipboard(:value)
  end

  d.step("the clipboard holds that cell's text") do
    d.check("the read came back") { CLIPBOARD.key?(:value) }
    d.check("it is the second column of the first row") do
      CLIPBOARD[:value] == "first message"
    end
  end

  d.step("win.copy-row copies the whole row with the separator from GSettings") do
    app.windows.first.window.activate_action("copy-row", nil)
    read_clipboard(:row)
  end

  d.step("the clipboard holds the row, tab separated") do
    d.check("the read came back") { CLIPBOARD.key?(:row) }
    d.check("it is the row joined with tabs") { CLIPBOARD[:row] == "k1\tfirst message" }
  end

  d.step("the column-separator preference changes what a copied row looks like") do
    Bobby::Settings.instance.set_string(Bobby::Settings::COLUMN_SEPARATOR, "markdown")
    app.windows.first.window.activate_action("copy-row", nil)
    read_clipboard(:markdown)
  end

  d.step("the row comes back as a markdown table row") do
    d.check("the read came back") { CLIPBOARD.key?(:markdown) }
    d.check("it is wrapped in pipes") { CLIPBOARD[:markdown] == "| k1 | first message |" }
    Bobby::Settings.instance.set_string(Bobby::Settings::COLUMN_SEPARATOR, "tabs")
    d.check("the preference went back to tabs") do
      Bobby::Settings.instance.column_separator == Bobby::Sqlite::ColumnSeparator::TABS
    end
  end

  d.step("win.copy-val declines a target it cannot read") do
    app.windows.first.window.activate_action("copy-val", GLib::Variant.new("not-a-pair"))
    read_clipboard(:unchanged)
  end

  d.step("the clipboard was left alone rather than cleared") do
    d.check("the read came back") { CLIPBOARD.key?(:unchanged) }
    d.check("it still holds the last row copied") do
      CLIPBOARD[:unchanged] == "| k1 | first message |"
    end
  end

  # -- The toasts -----------------------------------------------------------
  #
  # The toast is the only thing that tells a user a copy worked, so both
  # titles are read back off the overlay and compared with upstream's format
  # strings byte for byte, and the dismiss-before-add that keeps a held-down
  # Ctrl+C from queueing a toast per repeat is observed rather than assumed.

  d.step("the overlay is watched, and emptied of what the copies left in it") do
    app.windows.first.then do |window|
      watch_toasts(window.overlay)
      window.window.present
      window.overlay.dismiss_all
      TOASTS.clear
    end
  end

  d.step("win.copy-row announces the row it copied") do
    # A dismissed toast fades out over a frame or two before libadwaita takes
    # its widget out of the overlay, so the emptiness is waited for rather
    # than assumed on the next tick.
    settle_until(40) { toast_widgets(app.windows.first.overlay).empty? }
    d.check("the overlay starts empty") do
      toast_widgets(app.windows.first.overlay).empty?
    end
    app.windows.first.window.activate_action("copy-row", nil)
  end

  d.step("the toast names the row by its one-based number, as upstream's does") do
    app.windows.first.then do |window|
      settle_until(40) { toast_widgets(window.overlay).length == 1 }
      d.check("one toast is on screen") { toast_widgets(window.overlay).length == 1 }
      d.check("its title is upstream's format, byte for byte") do
        toast_titles(window.overlay) == ["Row 1 copied to clipboard"]
      end
      d.check("the overlay was handed exactly one toast") { TOASTS.length == 1 }
      d.check("the toast itself carries that title") do
        TOASTS.first.title == "Row 1 copied to clipboard"
      end
      d.check("it times out after upstream's two seconds") { TOASTS.first.timeout == 2 }
      window.window.activate_action("copy-row", nil)
    end
  end

  d.step("a second copy dismisses the first toast rather than queueing it") do
    app.windows.first.then do |window|
      d.check("the overlay was handed a second toast") { TOASTS.length == 2 }
      settle_until(40) { toast_widgets(window.overlay).length <= 1 }
      d.check("but only one of them is on screen") do
        toast_widgets(window.overlay).length == 1
      end
      window.overlay.dismiss_all
      TOASTS.clear
    end
  end

  d.step("win.copy-val quotes the value it copied") do
    app.windows.first.window.activate_action("copy-val", GLib::Variant.new("0:1"))
  end

  d.step("the toast is upstream's tabular-figures markup around the value") do
    app.windows.first.then do |window|
      settle_until(40) { toast_widgets(window.overlay).length == 1 }
      d.check("one toast is on screen") { toast_widgets(window.overlay).length == 1 }
      d.check("its title is upstream's markup, byte for byte") do
        toast_titles(window.overlay) ==
          ["<span font_features='tnum=1'>\u2018first message\u2019  copied to clipboard</span>"]
      end
      d.check("it times out after two seconds too") { TOASTS.last.timeout == 2 }
      window.overlay.dismiss_all
      TOASTS.clear
    end
  end

  # -- Switching tables ------------------------------------------------------

  d.step("win.table switches to another of the database's tables") do
    app.windows.first.window.activate_action("table", GLib::Variant.new("1"))
  end

  d.step("the people table is showing, with all six of its columns") do
    app.windows.first.then do |window|
      d.check("the window's index moved") { window.table_index == 1 }
      d.check("the action's state moved with it") do
        window.switch_table_action.action.state.to_s == "1"
      end
      d.check("the switcher's label names the new table") { window.switcher.label == "people" }
      d.check("the content is the new table") { window.content.table.name.to_s == "people" }
      d.check("it has seven view columns: six plus the index") do
        window.content.view_columns.length == 7
      end
      d.check("the old table's column view is out of the layout") do
        descendants(window.layout).grep(Gtk::ColumnView).length == 1
      end
      d.check("three rows are in the model") { window.content.model.n_items == 3 }
      d.check("newest first, so row one is id 3") do
        window.content.row_at(0).cell(0).value == 3
      end
      d.check("the blob cell shows a byte count") do
        window.content.row_at(2).cell(3).to_s == "8 BYTES"
      end
      d.check("the NULL cell shows an em dash") do
        window.content.row_at(1).cell(3).to_s == Bobby::Sqlite::Affinity::EM_DASH
      end
      d.check("a text column is wider than a default one") do
        window.content.view_columns[2].fixed_width == Bobby::Widgets::Content::TEXT_WIDTH &&
          window.content.view_columns[1].fixed_width == Bobby::Widgets::Content::DEFAULT_WIDTH
      end
      d.check("the blob column is fixed and not resizable") do
        window.content.view_columns[4].fixed_width == Bobby::Widgets::Content::BLOB_WIDTH &&
          !window.content.view_columns[4].resizable?
      end
    end
    d.shot("07-people-table")
  end

  # -- A REAL cell, and the byte-counted copy cutoff ------------------------

  d.step("the REAL cells render the way Rust's Display for f64 writes a float") do
    app.windows.first.content.then do |content|
      d.check("an integral REAL loses its trailing .0") do
        content.row_at(2).cell(2).to_s == "1"
      end
      d.check("and that is the text the cell's own label carries") do
        value_cells(content.column_view, 3).map(&:text).include?("1")
      end
      d.check("the tooltip says the same thing, not REAL 1.0") do
        value_cells(content.column_view, 3).find { |label| label.text == "1" }
          .then { |label| label&.parent&.tooltip_text == "REAL 1" }
      end
      d.check("a very large REAL is written in full rather than as an exponent") do
        content.row_at(1).cell(2).to_s == "1#{"0" * 300}"
      end
      d.check("and the label carries all three hundred and one digits") do
        value_cells(content.column_view, 3).map(&:text).include?("1#{"0" * 300}")
      end
      d.check("a fractional REAL is unchanged") do
        content.row_at(0).cell(2).to_s == "3.5"
      end
    end
  end

  d.step("copying an integral REAL puts the cell's own text on the clipboard") do
    app.windows.first.window.activate_action("copy-val", GLib::Variant.new("2:2"))
    read_clipboard(:real)
  end

  d.step("the clipboard holds 1 rather than 1.0") do
    d.check("the read came back") { CLIPBOARD.key?(:real) }
    d.check("it is what the cell shows") { CLIPBOARD[:real] == "1" }
    app.windows.first.then do |window|
      window.overlay.dismiss_all
      TOASTS.clear
      window.window.activate_action("copy-val", GLib::Variant.new("2:1"))
    end
  end

  d.step("a value with markup characters in it is escaped into the title") do
    app.windows.first.then do |window|
      settle_until(40) { toast_widgets(window.overlay).length == 1 }
      d.check("the toast is on screen") { toast_widgets(window.overlay).length == 1 }
      d.check("< > and & came through escaped, so Pango keeps the characters") do
        toast_titles(window.overlay) ==
          ["<span font_features='tnum=1'>\u2018Ada &lt;&amp;&gt;\u2019  copied to clipboard</span>"]
      end
      window.overlay.dismiss_all
      TOASTS.clear
      window.window.activate_action("copy-val", GLib::Variant.new("1:4"))
    end
  end

  d.step("a 94-byte value is announced, because upstream counts bytes") do
    app.windows.first.then do |window|
      d.check("the value is 47 characters and 94 bytes") do
        [ANNOUNCED_NOTE.length, ANNOUNCED_NOTE.bytesize] == [47, 94]
      end
      d.check("a toast was added") { TOASTS.length == 1 }
      d.check("it quotes the value") do
        toast_titles(window.overlay) ==
          ["<span font_features='tnum=1'>\u2018#{ANNOUNCED_NOTE}\u2019  copied to clipboard</span>"]
      end
      window.overlay.dismiss_all
      TOASTS.clear
      window.window.activate_action("copy-val", GLib::Variant.new("0:4"))
    end
  end

  d.step("a 96-byte value of 48 characters is copied silently") do
    app.windows.first.then do |window|
      d.check("the value is 48 characters and 96 bytes") do
        [SILENT_NOTE.length, SILENT_NOTE.bytesize] == [48, 96]
      end
      d.check("no toast was added, as upstream adds none past the cutoff") do
        TOASTS.empty?
      end
      settle_until(40) { toast_widgets(window.overlay).empty? }
      d.check("and none is on screen") { toast_widgets(window.overlay).empty? }
      d.check("the title upstream builds for it and shows nowhere is ported") do
        Bobby::Actions::WinCopyVal::LONG_TITLE == "Copied to clipboard"
      end
      read_clipboard(:silent)
    end
  end

  d.step("the long value reached the clipboard all the same") do
    d.check("the read came back") { CLIPBOARD.key?(:silent) }
    d.check("it is the whole ninety-six bytes") { CLIPBOARD[:silent] == SILENT_NOTE }
  end

  d.step("the view is a table too, read without a rowid") do
    app.windows.first.window.activate_action("table", GLib::Variant.new("2"))
  end

  d.step("the view's rows came back in file order") do
    app.windows.first.then do |window|
      d.check("the view is showing") { window.content.table.name.to_s == "people_view" }
      d.check("it knows it is a view") { window.content.table.view? }
      d.check("its two columns plus the index are there") do
        window.content.view_columns.length == 3
      end
      d.check("its rows are in the order the view returns them") do
        window.content.row_at(0).cell(0).to_s == "Ada <&>"
      end
      d.check("a view's columns keep the declared types PRAGMA table_info gives") do
        window.content.columns.drop(1).map { |column| [column.name, column.affinity.type] } ==
          [
            ["name", Bobby::Sqlite::Affinity::TEXT],
            ["score", Bobby::Sqlite::Affinity::REAL],
          ]
      end
      d.check("and the reserved index column in front of them has neither") do
        window.content.columns.first.name == "" &&
          window.content.columns.first.affinity.type == Bobby::Sqlite::Affinity::NULL
      end
    end
    d.shot("08-view")
  end

  d.step("a target that is not an index is refused, and the state still follows") do
    app.windows.first.window.activate_action("table", GLib::Variant.new("99"))
  end

  d.step("the window stayed on the view it was showing") do
    app.windows.first.then do |window|
      d.check("the state took the target, as upstream's does") do
        window.switch_table_action.action.state.to_s == "99"
      end
      d.check("but the content did not move") do
        window.content.table.name.to_s == "people_view"
      end
      d.check("and neither did the index") { window.table_index == 2 }
      window.window.activate_action("table", GLib::Variant.new("1"))
    end
  end

  # -- Reload ----------------------------------------------------------------

  d.step("the big table is opened, which is one that can be scrolled") do
    app.windows.first.window.present
    app.windows.first.window.activate_action("table", GLib::Variant.new("3"))
  end

  # Four hundred rows take more than one tick to lay out, and until the
  # ScrolledWindow has been allocated its adjustments have an upper bound of
  # zero and clamp anything set on them to it. So the table is given a tick to
  # settle, and the allocation is asserted rather than assumed — otherwise the
  # scroll offsets the next step sets would silently be zero and the reload
  # would be seen to carry a scroll position it never had.
  d.step("the big table lays out, so its scroll offsets mean something") do
    app.windows.first.content.scroller.then do |scroller|
      settle_until { scroller.allocated_height.positive? }
      d.check("the scrolled window has a height") { scroller.allocated_height.positive? }
      d.check("so the vertical adjustment has a range to scroll in") do
        scroller.vadjustment.upper > scroller.vadjustment.page_size
      end
    end
  end

  d.step("win.reload re-reads the file, keeping the table and the scroll") do
    app.windows.first.then do |window|
      d.check("the big table is showing") { window.content.table.name.to_s == "zbig" }
      d.check("all four hundred rows are in the model") do
        window.content.model.n_items == 400
      end
      window.content.scroll_position = [0.0, 120.0]
      d.check("the scroll offsets took") { window.content.scroll_position.last == 120.0 }
      @old_content = window.content
      @old_connection = window.database.connection
      window.window.activate_action("reload", nil)
    end
  end

  d.step("the table is the same one, rebuilt, over a new connection") do
    app.windows.first.then do |window|
      d.check("it is still in the content state") { window.state == :content }
      d.check("the content widget was rebuilt") { !window.content.equal?(@old_content) }
      d.check("the old connection was closed") { @old_connection.closed? }
      d.check("the new one is open") { !window.database.connection.closed? }
      d.check("the same table is showing") { window.content.table.name.to_s == "zbig" }
      d.check("the rows are back") { window.content.model.n_items == 400 }
      d.check("only one column view is in the layout") do
        descendants(window.layout).grep(Gtk::ColumnView).length == 1
      end
      d.check("the banner survived the reload") do
        window.layout.first_child.equal?(window.banner)
      end
    end
  end

  d.step("the scroll offsets came back on the idle tick") do
    app.windows.first.then do |window|
      d.check("the vertical offset was reapplied") do
        window.content.scroll_position.last == 120.0
      end
      window.content.scroll_position = [0.0, 0.0]
      window.window.activate_action("table", GLib::Variant.new("1"))
    end
  end

  # -- The preferences dialog ------------------------------------------------

  d.step("app.preferences opens the preferences dialog") do
    app.app.lookup_action("preferences").activate(nil)
  end

  d.step("the dialog is showing, with upstream's two groups and four rows") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.then do |dialog|
        d.check("it is an Adwaita::PreferencesDialog") do
          dialog.is_a?(Adwaita::PreferencesDialog)
        end
        d.check("it is visible") { dialog.visible? }
        d.check("its page is titled Preferences") do
          dialog.page.title == Bobby::PreferencesDialog::PAGE_TITLE
        end
        d.check("the first group keeps upstream's escaped ampersand") do
          dialog.rows_group.title == "Rows &amp; Columns"
        end
        d.check("the second group is Appearance") do
          dialog.appearance_group.title == "Appearance"
        end
        d.check("the row-numbers switch is on, as the key is") do
          dialog.row_numbers_row.active? == Bobby::Settings.instance.row_numbers?
        end
        d.check("the monospace switch is off, as the key is") do
          !dialog.monospace_row.active?
        end
        d.check("the row-order combo offers two choices") do
          dialog.row_order_row.model.n_items == 2
        end
        d.check("and sits on the stored one") do
          dialog.row_order_row.selected ==
            Bobby::Settings.instance.selected_index(Bobby::Settings::ROW_ORDER)
        end
        d.check("the separator combo offers four") do
          dialog.column_separator_row.model.n_items == 4
        end
        d.check("with upstream's subtitle") do
          dialog.column_separator_row.subtitle == Bobby::PreferencesDialog::COLUMN_SEPARATOR_SUBTITLE
        end
        # An Adwaita dialog presented over a Gtk::ApplicationWindow rather than
        # an Adwaita one falls back to a window of its own, so the dialog's root
        # is the picture; shooting the main window would show only the window.
        d.shot("09-preferences", dialog.root)
      end
  end

  d.step("turning the row-numbers switch off hides the index column") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.row_numbers_row.active = false
  end

  d.step("the key, the window and the column all followed") do
    d.check("the GSettings key is off") { !Bobby::Settings.instance.row_numbers? }
    app.windows.first.content.then do |content|
      d.check("the index column is hidden") { !content.index_column.visible? }
      d.check("the other columns are still visible") do
        content.view_columns.drop(1).all?(&:visible?)
      end
      d.check("no index cell is on screen any more") do
        labels_in(content.column_view).none? do |label|
          label.has_css_class?("dimmed") && label.text == "1"
        end
      end
    end
    d.shot("10-no-row-numbers")
  end

  d.step("and turning it back on shows it again") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.row_numbers_row.active = true
  end

  d.step("the index column is back") do
    d.check("the GSettings key is on") { Bobby::Settings.instance.row_numbers? }
    d.check("the index column is visible") do
      app.windows.first.content.index_column.visible?
    end
    d.check("force_redraw left every column visible") do
      app.windows.first.content.view_columns.all?(&:visible?)
    end
  end

  d.step("changing the row order reloads the window with the other query") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.row_order_row.selected = 1
  end

  d.step("the rows came back oldest first") do
    d.check("the key took the schema's value for that position") do
      Bobby::Settings.instance.gio.get_string(Bobby::Settings::ROW_ORDER) == "oldest-first"
    end
    d.check("the settings object reads it as ascending") do
      Bobby::Settings.instance.row_order == Bobby::Sqlite::RowOrder::ASCENDING
    end
    app.windows.first.then do |window|
      d.check("the reopened database was given that order") do
        window.database.row_order == Bobby::Sqlite::RowOrder::ASCENDING
      end
      d.check("the same table is still showing") { window.content.table.name.to_s == "people" }
      d.check("and row one is id 1 now, not id 3") do
        window.content.row_at(0).cell(0).value == 1
      end
    end
  end

  d.step("the monospace preference reloads and restyles the value cells") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.monospace_row.active = true
  end

  d.step("every value cell is monospace now") do
    d.check("the key is on") { Bobby::Settings.instance.monospace_font? }
    app.windows.first.content.then do |content|
      d.check("the content was rebuilt by the reload") { content.model.n_items == 3 }
      d.check("the value cells carry the monospace class") do
        value_cells(content.column_view, 1).then do |cells|
          !cells.empty? && cells.all? { |label| label.has_css_class?("monospace") }
        end
      end
    end
    d.shot("11-monospace")
  end

  d.step("the preferences the drive changed are put back") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppPreferences) }
      .dialog.then do |dialog|
        dialog.monospace_row.active = false
        dialog.row_order_row.selected = 0
        dialog.close
      end
    d.check("monospace is off again") { !Bobby::Settings.instance.monospace_font? }
    d.check("the order is newest first again") do
      Bobby::Settings.instance.row_order == Bobby::Sqlite::RowOrder::DESCENDING
    end
  end

  # -- The shortcuts dialog --------------------------------------------------

  d.step("app.shortcuts opens the shortcuts dialog") do
    app.app.lookup_action("shortcuts").activate(nil)
  end

  d.step("it lists upstream's six shortcuts, and each one is really registered") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppShortcuts) }
      .dialog.then do |dialog|
        d.check("it is an Adwaita::ShortcutsDialog") do
          dialog.is_a?(Adwaita::ShortcutsDialog)
        end
        d.check("it is visible") { dialog.visible? }
        d.check("it has a General section and a Tables section") do
          Bobby::ShortcutsDialog::SECTIONS.keys == ["General", "Tables"]
        end
        d.check("General lists five items, as upstream's does") do
          Bobby::ShortcutsDialog::SECTIONS["General"].length == 5
        end
        d.check("Tables lists one") do
          Bobby::ShortcutsDialog::SECTIONS["Tables"].length == 1
        end
        {
          "Open File"     => "app.open",
          "Open Menu"     => "app.open-menu",
          "Reload Window" => "win.reload",
          "Close Window"  => "win.close",
          "Quit"          => "app.quit",
          "Copy Row"      => "win.copy-row",
        }.each do |label, action|
          Bobby::ShortcutsDialog::SECTIONS.values.flatten(1)
            .find { |item| item.first == label }.then do |item|
              d.check("#{label} is listed") { !item.nil? }
              d.check("#{label}'s accelerator is the one #{action} is bound to") do
                accel_equal?(app.app.get_accels_for_action(action), [item.last])
              end
            end
        end
        d.shot("12-shortcuts", dialog.root)
        dialog.close
      end
  end

  # -- The about dialog ------------------------------------------------------

  d.step("app.about opens the about dialog") do
    app.app.lookup_action("about").activate(nil)
  end

  d.step("it credits the app with upstream's own fields") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppAbout) }
      .dialog.then do |dialog|
        d.check("it is an Adwaita::AboutDialog") { dialog.is_a?(Adwaita::AboutDialog) }
        d.check("it is visible") { dialog.visible? }
        d.check("its icon is the application id") { dialog.application_icon == Bobby::App::ID }
        d.check("its name is bobby") { dialog.application_name == Bobby::App::NAME }
        d.check("the developer is upstream's") do
          dialog.developer_name == Bobby::AboutDialog::DEVELOPER
        end
        d.check("the version is the gem's") { dialog.version == Bobby::Rb::VERSION }
        d.check("the website is upstream's repository") do
          dialog.website == Bobby::App::HOMEPAGE
        end
        d.check("the issue url is upstream's tracker") do
          dialog.issue_url == Bobby::App::ISSUE_URL
        end
        d.check("the copyright is upstream's") do
          dialog.copyright == Bobby::AboutDialog::COPYRIGHT
        end
        d.check("the licence is GPL 3") { dialog.license_type == Gtk::License::GPL_3_0 }
        d.shot("13-about", dialog.root)
        dialog.close
      end
  end

  # -- The file dialog and the drop target ----------------------------------

  d.step("the file dialog is built behind the two filters upstream sets") do
    APP.app_actions.find { |action| action.is_a?(Bobby::Actions::AppOpen) }
      .dialog.then do |file_dialog|
        d.check("it is a Gtk::FileDialog") { file_dialog.dialog.is_a?(Gtk::FileDialog) }
        d.check("it is modal") { file_dialog.dialog.modal? }
        d.check("it carries two filters") { file_dialog.filters.n_items == 2 }
        d.check("the first is named SQLite Databases") do
          file_dialog.sqlite_filter.name == Bobby::FileDialog::SQLITE_FILTER_NAME
        end
        d.check("the second is All Files") do
          file_dialog.all_filter.name == Bobby::FileDialog::ALL_FILTER_NAME
        end
        d.check("its gvariant carries all four of upstream's patterns") do
          file_dialog.sqlite_filter.to_gvariant.to_s.then do |description|
            Bobby::FileDialog::SQLITE_PATTERNS.all? { |p| description.include?(p) }
          end
        end
        d.check("the sqlite filter matches a database name and not a text one") do
          Bobby::FileDialog::SQLITE_PATTERNS.map { |pattern| pattern.sub("*", "data") }
            .all? { |name| file_dialog.sqlite_filter.match(file_info(name)) } &&
            !file_dialog.sqlite_filter.match(file_info("notes.txt"))
        end
        d.check("the all-files filter matches anything") do
          file_dialog.all_filter.match(file_info("notes.txt")) &&
            file_dialog.all_filter.match(file_info("data.db"))
        end
        d.check("the opener it hands its files to is the application") do
          file_dialog.opener.equal?(APP)
        end
      end
  end

  d.step("the window's drop target accepts a file list and routes it to the opener") do
    app.windows.first.drop_target.then do |target|
      d.check("the controller is a Gtk::DropTarget") do
        target.controller.is_a?(Gtk::DropTarget)
      end
      d.check("it is on the window") do
        app.windows.first.window.observe_controllers.to_a.include?(target.controller)
      end
      d.check("it accepts a GdkFileList") do
        target.controller.formats.to_s.include?("GdkFileList")
      end
      d.check("and copies rather than moves, as upstream's does") do
        target.controller.actions == :copy
      end
      d.check("its opener is the application") { target.opener.equal?(APP) }
      d.check("a drop of something that is not a file list is still accepted") do
        target.controller.signal_emit(
          "drop",
          GLib::Value.new(GLib::Type::INT, 3),
          0.0,
          0.0,
        )
      end
      d.check("and opened nothing") { app.windows.length == 1 }
    end
  end

  # -- A second file, a second window ---------------------------------------

  d.step("opening a second file while one is open makes a second window") do
    APP.open_files([gfile(OTHER_DB)])
  end

  d.step("the two windows hold one database each") do
    d.check("there are two windows") { app.windows.length == 2 }
    d.check("and two toplevels") { Gtk::Window.list_toplevels.length == 2 }
    d.check("the first still holds the fixture") { app.windows.first.key == MAIN_DB }
    d.check("the second holds the other file") { app.windows.last.key == OTHER_DB }
    app.windows.last.then do |window|
      d.check("it is in its content state") { window.state == :content }
      d.check("its one table is showing") { window.content.table.name.to_s == "widgets" }
      d.check("its switcher names it") { window.switcher.label == "widgets" }
      d.check("its switcher's Views section is empty") { window.switcher.views.empty? }
      d.check("its title is that file's basename") { window.window.title == "other.db" }
    end
    # A brand new window has nothing to paint until it has been realised and
    # allocated, and a snapshot of it then produces no render node at all.
    app.windows.last.window.then do |second|
      settle_until(20) { second.realized? && second.allocated_height.positive? }
      d.check("the second window has been realised and laid out") do
        second.realized? && second.allocated_height.positive?
      end
      d.shot("14-second-window", second)
    end
  end

  d.step("opening a file that is already open raises its window instead") do
    APP.open_files([gfile(MAIN_DB)])
  end

  d.step("no third window was made") do
    d.check("there are still two windows") { app.windows.length == 2 }
    d.check("and still two toplevels") { Gtk::Window.list_toplevels.length == 2 }
    d.check("the fixture's window is the active one again") do
      app.app.active_window == app.windows.first.window
    end
  end

  d.step("reopening a file in the window that holds it rebuilds its switcher") do
    app.windows.last.then do |window|
      @other_window = window
      window.load(gfile(MAIN_DB))
    end
  end

  d.step("the second window shows the fixture, with the fixture's tables") do
    @other_window.then do |window|
      d.check("it keyed itself by the new file") { window.key == MAIN_DB }
      d.check("its switcher's menu was rebuilt, not left stale") do
        menu_items(window.switcher.menu).map(&:first) == ["Views – 1", "Tables – 3"]
      end
      d.check("the view is in it now") { window.switcher.views.length == 1 }
      d.check("the switcher is packed only once, however many files it shows") do
        descendants(window.header_bar).grep(Gtk::MenuButton).length == 2
      end
    end
  end

  d.step("win.close closes that window and leaves the other alone") do
    @other_window.then do |window|
      @closed_connection = window.database.connection
      window.window.activate_action("close", nil)
    end
  end

  d.step("the window is gone, its database is closed, the first survives") do
    d.check("one window is left") { app.windows.length == 1 }
    d.check("one toplevel is left") { Gtk::Window.list_toplevels.length == 1 }
    d.check("the application dropped the closed one from its list") do
      !app.windows.include?(@other_window)
    end
    d.check("its database connection was closed") { @closed_connection.closed? }
    d.check("the surviving window still holds the fixture") do
      app.windows.first.key == MAIN_DB && !app.windows.first.database.connection.closed?
    end
    d.check("and is still showing its table") { app.windows.first.state == :content }
    d.shot("15-after-close")
  end

  d.step("a window that is empty again is the one a new file goes into") do
    app.windows.first.show_empty_state
  end

  d.step("the empty state came back, and took the file without a new window") do
    app.windows.first.then do |window|
      d.check("the window reports itself empty") { window.empty? }
      d.check("its key is gone") { window.key.nil? }
      d.check("the status page is the content again") do
        window.toolbar_view.content.equal?(window.empty_page)
      end
      d.check("the header bar keeps the border it earned, as upstream's does") do
        window.toolbar_view.top_bar_style == :raised_border
      end
      d.check("the title is Bobby again") do
        window.window.title == Bobby::Window::EMPTY_TITLE
      end
      d.shot("16-empty-again")
    end
    APP.open_files([gfile(OTHER_DB)])
  end

  d.step("the empty window took it rather than a new one being made") do
    d.check("there is still one window") { app.windows.length == 1 }
    d.check("and it holds the file") { app.windows.first.key == OTHER_DB }
    d.check("in its content state") { app.windows.first.state == :content }
  end

  d.step("reload on an empty window does nothing rather than raising") do
    app.windows.first.then do |window|
      window.show_empty_state
      window.window.activate_action("reload", nil)
      d.check("the window is still empty") { window.empty? }
      d.check("and still shows the status page") do
        window.toolbar_view.content.equal?(window.empty_page)
      end
      d.check("copy-row with no table copies nothing rather than raising") do
        window.window.activate_action("copy-row", nil)
        window.content.nil?
      end
    end
  end

  # The regression this drive found: window_toggle_row_order reloads the active
  # window, and a window in its error state has no database to re-read. The
  # port reached into it anyway and the NoMethodError came out inside the
  # GSettings handler, which ends the process.
  d.step("changing a preference while a window shows an error does not crash") do
    app.windows.first.then do |window|
      window.load(gfile(NOT_A_DB))
      d.check("the window is in its error state") { window.state == :error }
      d.check("with no database behind it") { window.database.nil? }
      window.window.present
    end
  end

  d.step("the preference changed and the error page is still there") do
    Bobby::Settings.instance.then do |settings|
      settings.set_string(Bobby::Settings::ROW_ORDER, "oldest-first")
      d.check("the key took the new value") do
        settings.row_order == Bobby::Sqlite::RowOrder::ASCENDING
      end
      app.windows.first.then do |window|
        d.check("the window is still in its error state") { window.state == :error }
        d.check("and still shows the reason it failed") do
          window.toolbar_view.content.equal?(window.error_page)
        end
      end
      settings.set_string(Bobby::Settings::ROW_ORDER, "newest-first")
      d.check("and the preference goes back") do
        settings.row_order == Bobby::Sqlite::RowOrder::DESCENDING
      end
      d.check("the process is still here to say so") { app.windows.length == 1 }
    end
  end

  d.step("reload on an error window is the same nothing") do
    app.windows.first.then do |window|
      window.window.activate_action("reload", nil)
      d.check("the window is still in its error state") { window.state == :error }
      d.check("and holds no database") { window.database.nil? }
      window.show_empty_state
    end
  end

  # -- The parts that need no display ---------------------------------------

  d.step("a file with no local path is reported, not opened") do
    capture_stderr { APP.handle_open(Gio::File.new_for_uri("https://example.com/x.db")) }
      .then do |printed|
        d.check("the message is upstream's") do
          printed.include?(Bobby::Application::NO_LOCAL_PATH)
        end
        d.check("no window was made for it") { app.windows.length == 1 }
      end
  end

  d.step("the app's identity is upstream's, and --env prints all of it") do
    Bobby::App.new.then do |info|
      d.check("the id is upstream's") { info.id == "studio.planetpeanut.Bobby" }
      d.check("the name and command are both bobby") do
        info.name == "bobby" && info.command == "bobby"
      end
      d.check("the icon is the id") { info.icon == Bobby::App::ID }
      d.check("the version is the gem's") { info.version == Bobby::Rb::VERSION }
      d.check("the prefix is upstream's Flatpak one") { info.prefix == "/app" }
      d.check("the config home follows XDG_CONFIG_HOME") do
        info.app_config_home == File.join(ENV.fetch("XDG_CONFIG_HOME"), "bobby")
      end
      d.check("so do the data and cache homes") do
        info.app_data_home == File.join(ENV.fetch("XDG_DATA_HOME"), "bobby") &&
          info.app_cache_home == File.join(ENV.fetch("XDG_CACHE_HOME"), "bobby")
      end
      d.check("--env prints the twelve fields upstream's does") do
        info.to_h.keys == [
          :id, :name, :command, :icon, :version, :is_flatpak, :prefix,
          :desktop_file, :appdata_file, :app_config_home, :app_data_home,
          :app_cache_home,
        ]
      end
      d.check("it is not a Flatpak here") { !info.flatpak? }
    end
    d.check("the version line is name and version") do
      Bobby::App.version_string == "bobby #{Bobby::Rb::VERSION}"
    end
    d.check("--deps names the SQLite the gem is linked against") do
      Bobby::App.deps == "SQLite #{SQLite3::SQLITE_VERSION}"
    end
    d.check("the drive is not running as root, so the refusal is not triggered") do
      !Bobby::App.runs_as_root?
    end
  end

  d.step("the CLI prints upstream's four options and leaves") do
    Bobby::Cli.new(Bobby::App.new).then do |cli|
      {
        "--version" => Bobby::App.version_string,
        "--deps"    => Bobby::App.deps,
        "--help"    => Bobby::Cli::USAGE,
        "--env"     => "studio.planetpeanut.Bobby",
      }.each do |option, expected|
        capture_stdout do
          begin
            cli.parse([option])
          rescue SystemExit => e
            @status = e.status
          end
        end.then do |printed|
          d.check("#{option} prints #{expected[0, 24].inspect}") { printed.include?(expected) }
          d.check("#{option} exits zero") { @status.zero? }
        end
      end
      d.check("--help lists all four options") do
        capture_stdout do
          begin
            cli.parse(["--help"])
          rescue SystemExit
            nil
          end
        end.include?(Bobby::Cli::OPTIONS_LINE)
      end
      d.check("a file argument falls through to the GUI") do
        @status = :not_called
        capture_stdout do
          begin
            cli.parse(["some.db"])
          rescue SystemExit => e
            @status = e.status
          end
        end
        @status == :not_called
      end
      d.check("so does no argument at all") do
        @status = :not_called
        capture_stdout do
          begin
            cli.parse([])
          rescue SystemExit => e
            @status = e.status
          end
        end
        @status == :not_called
      end
      d.check("an option after the first is left alone, as upstream leaves it") do
        @status = :not_called
        capture_stdout do
          begin
            cli.parse(["file.db", "--version"])
          rescue SystemExit => e
            @status = e.status
          end
        end
        @status == :not_called
      end
    end
  end

  d.step("the preflight runs the CLI and refuses nothing else here") do
    @status = :not_called
    capture_stdout do
      begin
        Bobby::Preflight.run(["--version"])
      rescue SystemExit => e
        @status = e.status
      end
    end.then do |printed|
      d.check("it printed the version line") { printed.include?(Bobby::App.version_string) }
      d.check("and exited zero") { @status.zero? }
    end
    @status = :not_called
    ENV["TERM"] = "xterm"
    capture_stdout do
      begin
        Bobby::Preflight.run([])
      rescue SystemExit => e
        @status = e.status
      end
    end
    d.check("with no option it returns and lets the GUI run") { @status == :not_called }
  end

  d.step("the log writes what upstream's log.rs writes") do
    d.check("log is a bare line") { capture_stdout { Bobby::Log.log("plain") } == "plain\n" }
    d.check("info is timestamped") do
      capture_stdout { Bobby::Log.info("x") }.match?(/\A\d\d:\d\d:\d\d \| x\n\z/)
    end
    d.check("debug is silent unless DEBUG is exactly 1") do
      ENV["DEBUG"] = "true"
      capture_stdout { Bobby::Log.debug("quiet") }.empty?
    end
    d.check("and speaks, dimmed, when it is") do
      ENV["DEBUG"] = "1"
      capture_stdout { Bobby::Log.debug("loud") }.then do |printed|
        printed.include?("loud") && printed.start_with?(Bobby::Log::ESCAPE_DIM)
      end
    end
    d.check("debug_struct pretty-prints an object") do
      ENV["DEBUG"] = "1"
      capture_stdout { Bobby::Log.debug_struct({ a: 1 }) }.include?("{a: 1}")
    end
    d.check("error goes to stderr, in red, with the app's prefix") do
      capture_stderr { Bobby::Log.error("bad") }.then do |printed|
        printed.include?("bobby error:") && printed.include?("bad") &&
          printed.start_with?(Bobby::Log::ESCAPE_RED)
      end
    end
    d.check("error_and_exit leaves with 255") do
      begin
        capture_stderr { Bobby::Log.error_and_exit("fatal") }
        false
      rescue SystemExit => e
        e.status == Bobby::Log::EXIT_ERROR
      end
    end
  ensure
    ENV.delete("DEBUG")
  end

  d.step("the clipboard helper installs text through GDK") do
    Bobby::Util.copy_to_clipboard("from-util")
    read_clipboard(:util)
  end

  d.step("and GDK hands it back") do
    d.check("the read came back") { CLIPBOARD.key?(:util) }
    d.check("it is what was put there") { CLIPBOARD[:util] == "from-util" }
  end

  # -- Leaving ---------------------------------------------------------------

  d.step("app.quit is wired to the application's quit") do
    app.app.lookup_action("quit").then do |action|
      d.check("it is a parameterless action") { action.parameter_type.nil? }
      d.check("it is enabled") { action.enabled? }
      d.check("there is a window for it to close") { app.windows.length == 1 }
      action.activate(nil)
    end
  end

  # If app.quit worked, the main loop is already gone and this step never runs.
  d.step("app.quit stopped the main loop") do
    d.check("the loop should have ended at app.quit, and did not") { false }
  end
end
