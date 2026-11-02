# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'adwaita'

require_relative 'actions/win_close'
require_relative 'actions/win_copy_row'
require_relative 'actions/win_copy_val'
require_relative 'actions/win_reload'
require_relative 'actions/win_switch_table'
require_relative 'settings'
require_relative 'sqlite/database'
require_relative 'widgets/button'
require_relative 'widgets/content'
require_relative 'widgets/drop_target'
require_relative 'widgets/menu'
require_relative 'widgets/switcher'

module Bobby
  # Window is one database, or one window waiting for one.
  #
  # Ported from upstream's src/gtk/windows/window.rs. It has three states and
  # swaps the ToolbarView's content between them:
  #
  #   empty   — the Browse Databases status page, with the open pill
  #   error   — the same page shape with dialog-error-symbolic and the reason
  #   content — a ToastOverlay over a Box holding the reload banner and the
  #             table, with the table switcher packed into the header bar
  #
  # The header bar's style is part of the state: flat while there is nothing
  # to read, raised-border once a table is on screen, so the column headers
  # have an edge to sit under.
  #
  # Upstream builds all of this from free functions that keep no references,
  # which is why it finds its own widgets again by walking the tree
  # (widget_by_name), stashes the Database on the window with
  # GObject::set_data, and marks an empty window by setting its widget name to
  # "1". None of that is needed here: the widgets are memoized accessors and
  # the Database is an attribute, so the window can be asked what it is
  # showing.
  #
  # The reload banner is built but never revealed, as upstream's is — the
  # file-change watch it belongs to is unwritten there. Its button activates
  # win.reload; upstream points it at "app.reload", which no action answers.
  class Window
    DEFAULT_WIDTH = 960
    DEFAULT_HEIGHT = 640

    EMPTY_TITLE = 'Bobby'
    EMPTY_ICON = 'studio.planetpeanut.Bobby-symbolic'
    EMPTY_HEADING = 'Browse Databases'
    EMPTY_DESCRIPTION = 'Drag and drop <b>SQLite files</b> here'

    ERROR_ICON = 'dialog-error-symbolic'
    ERROR_HEADING = 'Unable to Open File'

    BANNER_TITLE = 'File has changed'
    BANNER_BUTTON = 'Reload'

    NO_TABLES = 'Table list empty'
    NO_SUCH_TABLE = 'Table does not exist'

    # opener is the Application: what a dropped file is handed to, since
    # Gio::Application#open cannot be called from Ruby.
    def initialize(application, settings: Settings.instance, opener: nil)
      @application = application
      @settings = settings
      @opener = opener
      @state = :empty
      @table_index = 0
    end

    attr_reader :application,
      :settings,
      :opener,
      :database,
      :content,
      :tables,
      :table_index,
      :state

    def build
      window.tap do |win|
        win.child = toolbar_view
        win.add_controller(drop_target.build)
        win.add_action(close_action.build)
        win.add_css_class('flat')

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)

          header_bar.pack_end(main_menu.build)
        end

        show_empty_state
      end
    end

    def present = window.present

    def close
      database&.close
      window.close
    end

    def empty? = state == :empty

    # What the application indexes its windows by: the path of the file this
    # window is showing, and nil while it is showing none. Upstream keeps the
    # same thing in the window's widget name.
    def key = @key

    # Opens a file into this window, in whichever state it ends up in.
    def load(file, table_name: nil)
      Sqlite::Database.from_file(file, settings.row_order).then do |db|
        show_content_state(db, table_name)
      end
    rescue Sqlite::Database::Error => e
      show_error_state(file, e.message)
    end

    def show_empty_state
      @state = :empty
      @key = nil
      @database = nil
      drop_content
      window.title = EMPTY_TITLE
      toolbar_view.content = empty_page
    end

    def show_error_state(file, message)
      @state = :error
      @key = file.path
      @database = nil
      drop_content
      error_page.description = message
      window.title = title_for(file)
      toolbar_view.content = error_page
    end

    # Re-reads the open file, keeping the table and the scroll offsets.
    #
    # The offsets are reapplied on an idle tick rather than straight away:
    # the new ColumnView has not been allocated yet, so its adjustments still
    # have an upper bound of zero and would clamp the values to it.
    #
    # A window with no database has nothing to re-read, and asking it to do so
    # anyway is reachable: the row-order and monospace-font preferences reload
    # the active window, which may be sitting in its error state. Upstream's
    # window_reload leaves with Err there — it looks its widgets up by name and
    # an error window has no "content" — and every caller discards that Err, so
    # nothing happens. This is that nothing. Before the guard was here, changing
    # either preference while a window showed the error state raised
    # NoMethodError inside the GSettings handler and took the process with it.
    def reload
      unless database.nil?
        content&.scroll_position.then do |position|
          current_table_name.then do |table_name|
            database&.close
            reopen(table_name)
            restore_scroll(position)
          end
        end
      end
    end

    # Shows another of this database's tables, which is what the win.table
    # action asks for.
    def switch_table(index)
      tables.to_a[index].then do |table|
        unless table.nil?
          @table_index = index
          switcher.label = table.name.to_s
          swap_content(table)
        end
      end
    end

    # The row-numbers preference. The redraw clears the column-separator
    # glitch that changing a column's visibility leaves behind.
    def toggle_row_numbers
      content.then do |showing|
        unless showing.nil?
          showing.force_redraw
          showing.row_numbers_visible = settings.row_numbers?
        end
      end
    end

    # The row-order and monospace-font preferences both change how the rows
    # are read or built, so upstream reloads the window for either.
    def toggle_by_reload
      unless empty?
        reload
      end
    end

    # Memoized widget methods

    # Gtk::ApplicationWindow rather than Adwaita::ApplicationWindow, which the
    # Ruby bindings cannot construct from an application object. The two differ
    # in how the content is set — Adwaita's is #content=, GTK's is #child= —
    # and in the titlebar: Gtk::Window draws a default one, which would sit
    # above the ToolbarView's own Adwaita::HeaderBar. An empty hidden widget in
    # the titlebar slot takes that row away and leaves the client-side
    # decorations on the header bar below it.
    def window
      @window ||= Gtk::ApplicationWindow.new(application).tap do |win|
        win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        win.titlebar = empty_titlebar
      end
    end

    def empty_titlebar
      @empty_titlebar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.visible = false
      end
    end

    # Flat is set once here and never set back, as upstream's window_new does:
    # showing content raises the border and nothing lowers it again, so a file
    # that fails to reopen keeps the border its predecessor earned.
    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.top_bar_style = :flat
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def overlay = @overlay ||= Adwaita::ToastOverlay.new

    def layout
      @layout ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.append(banner)
      end
    end

    def banner
      @banner ||= Adwaita::Banner.new(BANNER_TITLE).tap do |b|
        b.button_label = BANNER_BUTTON
        b.action_name = 'win.reload'
        b.button_style = :suggested
      end
    end

    def empty_page
      @empty_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = EMPTY_ICON
        page.title = EMPTY_HEADING
        page.description = EMPTY_DESCRIPTION
        page.child = empty_button.build
        page.hexpand = true
        page.vexpand = true
      end
    end

    def error_page
      @error_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = ERROR_ICON
        page.title = ERROR_HEADING
        page.child = error_button.build
        page.hexpand = true
        page.vexpand = true
      end
    end

    def empty_button = @empty_button ||= Widgets::OpenButton.new

    def error_button = @error_button ||= Widgets::OpenButton.new

    def main_menu = @main_menu ||= Widgets::Menu.new(application)

    def drop_target = @drop_target ||= Widgets::DropTarget.new(opener)

    def switcher = @switcher ||= Widgets::Switcher.new(tables.to_a)

    def close_action = @close_action ||= Actions::WinClose.new(self)

    def copy_row_action = @copy_row_action ||= Actions::WinCopyRow.new(self)

    def copy_val_action = @copy_val_action ||= Actions::WinCopyVal.new(self)

    def reload_action = @reload_action ||= Actions::WinReload.new(self)

    def switch_table_action = @switch_table_action ||= Actions::WinSwitchTable.new(self)

    private

      def show_content_state(db, table_name)
        @database = db
        @tables = db.tables
        @key = db.path

        select_table(table_name).then do |table|
          if table.nil?
            show_error_state(db.file, missing_table_message)
          else
            enter_content_state(table)
          end
        end
      end

      def enter_content_state(table)
        @state = :content
        @table_index = tables.index(table)

        window.title = title_for(database.file)
        pack_switcher
        switcher.tables = tables
        switcher.label = table.name.to_s

        swap_content(table)
        overlay.child = layout
        toolbar_view.content = overlay
        toolbar_view.top_bar_style = :raised_border

        install_content_actions
      end

      # The switcher is packed into the header bar once and then kept: it is
      # the same widget for every file this window ever shows.
      def pack_switcher
        unless @switcher_packed
          header_bar.pack_start(switcher.build)
          @switcher_packed = true
        end
      end

      def swap_content(table)
        Widgets::Content.new(database, table, settings: settings).tap do |new_content|
          unless content.nil?
            layout.remove(content.scroller)
          end

          @content = new_content
          layout.append(new_content.build)
        end
      end

      def install_content_actions
        unless @content_actions_installed
          window.add_action(copy_row_action.build)
          window.add_action(copy_val_action.build)
          window.add_action(reload_action.build)
          window.add_action(switch_table_action.build)
          @content_actions_installed = true
        end

        switch_table_action.action.set_state(GLib::Variant.new(table_index.to_s))
      end

      def reopen(table_name)
        drop_content
        load(database.file, table_name: table_name)
      end

      # Upstream's states each replace the window's whole child, so leaving the
      # content state takes the table with it: win.copy-row then looks for a
      # ColumnView in the window, finds none and does nothing. Here the table
      # is both a widget in the layout box and an attribute, so both have to
      # go — otherwise an emptied window still answers win.copy-row from the
      # table it used to show, and the next table would be appended below the
      # one that is no longer on screen.
      def drop_content
        unless @content.nil?
          layout_children.each { |child| layout.remove(child) }
          @content = nil
        end
      end

      # Everything the layout holds except the banner, which belongs to the
      # window rather than to one table.
      def layout_children
        [].tap do |children|
          child = layout.first_child
          while child
            unless child == banner
              children << child
            end
            child = child.next_sibling
          end
        end
      end

      def restore_scroll(position)
        unless position.nil?
          GLib::Idle.add do
            apply_scroll(position)
            false
          end
        end
      end

      def apply_scroll(position)
        content.then do |showing|
          unless showing.nil?
            showing.scroll_position = position
          end
        end
      end

      def current_table_name
        tables.to_a[table_index].then { |table| table&.name&.to_s }
      end

      def select_table(table_name)
        if table_name.nil?
          tables.first
        else
          tables.find { |table| table.name.to_s == table_name }
        end
      end

      def missing_table_message
        if tables.empty?
          NO_TABLES
        else
          NO_SUCH_TABLE
        end
      end

      def title_for(file)
        File.basename(file.path.to_s).then do |name|
          if name.empty?
            EMPTY_TITLE
          else
            name
          end
        end
      end
  end
end
