# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Widgets
    # Switcher is the table picker packed into the start of the header bar:
    # a MenuButton labelled with the open table, over a menu split into a
    # Views section and a Tables section.
    #
    # Ported from upstream's src/gtk/widgets/switcher.rs. Each item targets
    # win.table with the table's index as its string target, which is what
    # makes the stateful win.table action able to tick the current one.
    #
    # Underscores in a table name are doubled, as upstream does, because
    # GMenu reads a single underscore as a mnemonic and would swallow it.
    #
    # Upstream keeps a window's first switcher for the life of the window and
    # only ever changes its label, so reopening a file whose tables have
    # changed leaves a stale menu behind. #tables= rebuilds the model instead.
    class Switcher
      TOOLTIP = 'Tables'

      def initialize(tables) = @tables = tables

      attr_reader :tables

      def build
        button.tap do |btn|
          tables.first.then do |table|
            unless table.nil?
              btn.label = table.name.to_s
            end
          end
        end
      end

      def label = button.label

      def label=(text)
        button.label = text
      end

      def tables=(tables)
        @tables = tables
        @menu = nil
        @view_section = nil
        @table_section = nil
        button.menu_model = menu
      end

      def button
        @button ||= Gtk::MenuButton.new.tap do |btn|
          btn.menu_model = menu
          btn.tooltip_text = TOOLTIP
        end
      end

      def menu
        @menu ||= Gio::Menu.new.tap do |m|
          m.append_section("Views – #{views.length}", view_section)
          m.append_section("Tables – #{plain_tables.length}", table_section)
        end
      end

      def view_section = @view_section ||= section_for(views)

      def table_section = @table_section ||= section_for(plain_tables)

      def views = tables.select(&:view?)

      def plain_tables = tables.reject(&:view?)

      private

        # The index is the one in the full table list, not in the section, so
        # win.table::<i> addresses the same list the window holds.
        def section_for(selection)
          Gio::Menu.new.tap do |section|
            selection.each do |table|
              section.append(escape(table.name.to_s), "win.table::#{tables.index(table)}")
            end
          end
        end

        def escape(name) = name.gsub('_', '__')
    end
  end
end
