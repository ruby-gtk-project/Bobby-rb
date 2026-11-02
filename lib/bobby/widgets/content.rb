# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative '../settings'
require_relative '../sqlite/affinity'
require_relative '../sqlite/cache'
require_relative '../sqlite/column'
require_relative 'item'

module Bobby
  module Widgets
    # Content is the table itself: a ScrolledWindow around a ColumnView, one
    # ColumnViewColumn per database column, and a right-click menu over the
    # cells.
    #
    # Ported from upstream's src/gtk/widgets/content.rs. Upstream's
    # content_new builds the whole thing in one function and then has to find
    # its pieces again by walking the widget tree; here each piece is a
    # memoized accessor, which is what lets the window reload, toggle row
    # numbers and read the selected row back without searching for anything.
    #
    # A reserved column is inserted at position 0 for the row numbers, so
    # every other column's index is one higher than its index in the table —
    # the offset Item::ValueCell#bind undoes.
    class Content
      # Upstream's per-affinity starting widths. Text gets more room because
      # it is the affinity most likely to be long; a blob shows a byte count,
      # which never grows, so its column is fixed.
      TEXT_WIDTH = 192
      DEFAULT_WIDTH = 128
      BLOB_WIDTH = 128

      # Two characters of slack on top of the widest row number, which is
      # what upstream adds before the margins.
      INDEX_PADDING_CHARS = 2

      def initialize(database, table, settings: Settings.instance)
        @database = database
        @table = table
        @settings = settings
      end

      attr_reader :database, :table, :settings

      def build
        scroller.tap do |sw|
          sw.child = column_view

          column_view.tap do |cv|
            view_columns.each { |view_column| cv.append_column(view_column) }
            cv.add_controller(click_gesture)

            click_gesture.signal_connect('pressed') do |gesture, _n_presses, x, y|
              open_context_menu(gesture, x, y)
            end
          end

          column_view.grab_focus
        end
      end

      # The Row behind a position in the model, or nil when the position is
      # past the end. Upstream's content.rs get_row.
      def row_at(position)
        selection.get_item(position).then { |item| item&.row }
      end

      def selected_position = selection.selected

      def selected_row = row_at(selected_position)

      # Whether the row-number column is shown. Upstream binds this to the
      # GSettings key through a property binding, then takes the binding back
      # out again with a note about a GTK rendering bug, so it is set by hand
      # here too.
      def row_numbers_visible=(visible)
        index_column.visible = visible
      end

      # HACK, upstream's content_force_redraw: hiding and re-showing every
      # column is what clears the column-separator glitch left behind when a
      # column's visibility changes.
      def force_redraw
        view_columns.each { |view_column| view_column.visible = false }
        view_columns.each { |view_column| view_column.visible = true }
      end

      # Take the model off the view before the content is let go.
      #
      # GTK's list-item manager asks the model for items from inside
      # gtk_list_base_dispose, and a Gtk::ColumnView whose Ruby wrapper is
      # freed by Ruby's garbage collector is disposed *during the sweep* —
      # ruby-gnome's holder_free calls g_object_unref there. The model is
      # Sqlite::Cache, whose get_item is Ruby, so GTK then calls Ruby from
      # inside a GC phase and ruby-gnome allocates a Ruby Integer for the
      # index it is passing: `[BUG] object allocation during garbage
      # collection phase`, and the process aborts. Clearing the view's model
      # while the window still holds the content leaves the manager nothing to
      # ask for, so the dispose that comes later is harmless. Every path that
      # stops showing a table calls this. Found by a 2,000-row reload loop; see
      # FINDINGS.md.
      def detach
        column_view.model = nil
      end

      # The scroll offsets, which win.reload carries across a reload.
      def scroll_position = [scroller.hadjustment.value, scroller.vadjustment.value]

      def scroll_position=(position)
        scroller.hadjustment.value = position.first
        scroller.vadjustment.value = position.last
      end

      # Memoized widget methods

      def scroller
        @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
          sw.vexpand = true
        end
      end

      def column_view
        @column_view ||= Gtk::ColumnView.new(selection).tap do |cv|
          cv.enable_rubberband = false
          cv.focusable = true
          cv.has_tooltip = true
          cv.reorderable = false
          cv.show_column_separators = true
          cv.show_row_separators = true
          cv.single_click_activate = true
          cv.tab_behavior = :cell
        end
      end

      def selection = @selection ||= Gtk::SingleSelection.new(model)

      # The cache is the model: upstream's DatabaseCacheModel is itself the
      # Gio::ListModel the view reads, and so is this one. It pages rows in as
      # the view asks for them and holds the RowObjects it has handed out,
      # which is what keeps their Row alive on the Ruby side. See
      # Sqlite::Cache.
      def cache = @cache ||= Sqlite::Cache.new(database, table)

      def model = cache

      def row_count = @row_count ||= database.row_count(table)

      # The table's columns with the reserved row-number column in front.
      def columns = @columns ||= [Sqlite::Column.index, *database.columns(table)]

      def view_columns
        @view_columns ||= columns.each_with_index.map do |column, index|
          view_column(column, index)
        end
      end

      def index_column = view_columns.first

      def click_gesture
        @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = Gdk::BUTTON_SECONDARY
        end
      end

      private

        def view_column(column, index)
          Gtk::ColumnViewColumn.new(title_for(column), factory_for(column, index)).tap do |vc|
            vc.id = index.to_s
            vc.resizable = true
            vc.expand = index == columns.length - 1

            if index.zero?
              size_index_column(vc)
            else
              size_value_column(vc, column)
            end
          end
        end

        def size_index_column(view_column)
          view_column.fixed_width = index_column_width
          view_column.resizable = false
          view_column.visible = settings.row_numbers?
        end

        def size_value_column(view_column, column)
          view_column.fixed_width = width_for(column.affinity)

          if column.affinity.type == Sqlite::Affinity::BLOB
            view_column.resizable = false
          end
        end

        def width_for(affinity)
          case affinity.type
          when Sqlite::Affinity::BLOB then BLOB_WIDTH
          when Sqlite::Affinity::TEXT then TEXT_WIDTH
          else DEFAULT_WIDTH
          end
        end

        # Wide enough for the largest row number the table can show, in the
        # monospace digits the index cells use.
        def index_column_width
          (Item::MARGIN * 2) +
            ((row_count.to_s.length + INDEX_PADDING_CHARS) * digit_width)
        end

        # Measured rather than assumed: the monospace font is whatever the
        # theme picked, so its advance width is only knowable from Pango.
        def digit_width
          Gtk::Label.new.tap { |l| l.add_css_class('monospace') }
            .create_pango_layout('0')
            .pixel_extents
            .last
            .width
        end

        def title_for(column)
          if column.primary_key?
            "#{column.name} #{Item::SYMBOL_KEY}"
          else
            column.name
          end
        end

        def factory_for(column, index)
          Gtk::SignalListItemFactory.new.tap do |factory|
            if index.zero?
              connect_index_factory(factory)
            else
              connect_value_factory(factory, column, index)
            end
          end
        end

        def connect_index_factory(factory)
          factory.signal_connect('setup') { |_, list_item| Item::IndexCell.setup(list_item) }
          factory.signal_connect('bind') { |_, list_item| Item::IndexCell.bind(list_item, row_count) }
        end

        def connect_value_factory(factory, column, index)
          factory.signal_connect('setup') do |_, list_item|
            Item::ValueCell.setup(list_item, settings.monospace_font?)
          end

          factory.signal_connect('bind') do |_, list_item|
            Item::ValueCell.bind(list_item, index, column.primary_key?)
          end
        end

        # Gtk::ColumnView does not report which cell a click landed in, so the
        # widget under the pointer is picked and its name — written by
        # Item::ValueCell — read back as the column index.
        def open_context_menu(gesture, x, y)
          column_view.pick(x, y, Gtk::PickFlags::NON_TARGETABLE).then do |picked|
            if picked.is_a?(Gtk::Label)
              cell_index_of(picked).then do |cell_index|
                unless cell_index.nil?
                  present_menu(
                    gesture,
                    cell_index,
                    x,
                    y,
                  )
                end
              end
            end
          end
        end

        # nil for the row-number column, which has nothing to copy.
        def cell_index_of(label)
          Integer(label.name, exception: false).then do |index|
            if !index.nil? && index.positive?
              index - 1
            end
          end
        end

        def present_menu(gesture, cell_index, x, y)
          gesture.widget.then do |widget|
            unless widget.nil?
              popover_for(cell_index, x, y).tap do |popover|
                popover.parent = widget
                popover.popup
              end
            end
          end
        end

        def popover_for(cell_index, x, y)
          Gtk::PopoverMenu.new(context_menu(cell_index)).tap do |popover|
            popover.has_arrow = false
            popover.pointing_to = Gdk::Rectangle.new(
              x.to_i,
              y.to_i,
              0,
              0,
            )
          end
        end

        # win.copy-val carries "row:column" as its target, which is how the
        # action knows which cell the menu was opened over.
        def context_menu(cell_index)
          Gio::Menu.new.tap do |menu|
            menu.append('Copy', "win.copy-val::#{selected_position}:#{cell_index}")
            menu.append('Copy Row', 'win.copy-row')
          end
        end
    end
  end
end
