# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative 'database'
require_relative 'row'

module Bobby
  module Sqlite
    # RowObject carries one Row through a Gio::ListModel.
    #
    # A list model can only hold GObjects, which is what upstream's
    # BoxedAnyObject is for. ruby-gnome has no BoxedAnyObject, so a minimal
    # registered GLib::Object with one attribute does the same job; the
    # content widget's bind handler reads #row off it.
    class RowObject < GLib::Object
      type_register

      attr_accessor :row

      def initialize(row = nil)
        super()
        @row = row
      end
    end

    # Cache is the list model the content widget's ColumnView reads.
    #
    # Ported from upstream's src/bobby/sqlite/cache.rs, where
    # DatabaseCacheModel is a custom Gio.ListModel: item(n) answers from a
    # BTreeMap, filling it on a miss with a 256-row page whose offset is
    # n - 128, then dropping every cached index further than 256 from n so a
    # long scroll does not grow without bound. n_items answers SELECT COUNT(*)
    # once and remembers it. Both numbers and both constants are upstream's.
    #
    # So a table is never read whole: opening one runs one COUNT and one
    # 256-row SELECT, and scrolling runs one SELECT per page crossed. That is
    # what "Scroll through tables and views of any size", the feature line the
    # port's own metainfo carries, means.
    #
    # The page comes from Database#page and not Database#rows, because
    # upstream's own paged query counts in rowids rather than in the index a
    # list model asks by. Row.page says what that costs.
    #
    # Implementing a Gio::ListModel from Ruby turns on one ordering detail:
    # `include Gio::ListModel` must come *after* `type_register`. Included
    # first, the GType is registered without the interface, every
    # g_list_model_* call fails its G_IS_LIST_MODEL assertion, and the model
    # silently answers 0 items — no exception, just an empty table. The
    # virtual_do_* methods must also be defined after the include, because
    # ruby-gnome binds each one to the interface's vfunc as it is defined.
    #
    # The cached RowObjects are held here on the Ruby side and that is not
    # redundant with the GObjects GTK holds. A GLib::Object subclass defined
    # in Ruby keeps its attributes in Ruby instance variables, and ruby-gnome
    # associates the Ruby half with the GObject only weakly: dropping the last
    # Ruby reference lets the Ruby object be collected while the GObject lives
    # on, and the next read hands back a freshly made RowObject whose #row is
    # nil. The table then renders blank. Eviction is therefore the one place
    # that may drop a live object, and the ±256 guard is what makes it safe:
    # no viewport is 256 rows tall, so nothing GTK is still showing is ever
    # evicted. Found by test/drive_bobby.rb; see FINDINGS.md.
    class Cache < GLib::Object
      type_register
      include Gio::ListModel

      # Upstream's CACHE_PAGE_SIZE and GUARD_RADIUS.
      CACHE_PAGE_SIZE = 256
      GUARD_RADIUS = 256

      def initialize(database, table)
        super()
        @database = database
        @table = table
        @cached_rows = {}
      end

      attr_reader :database, :table, :cached_rows

      # Upstream's n_items: the count is read once and remembered, and a
      # failed count is 0 rather than an error, as its unwrap_or(0) is.
      def row_count
        @row_count ||= begin
          database.row_count(table)
        rescue Database::Error, SQLite3::Exception
          0
        end
      end

      # The page offset a miss at this index reads from: upstream's
      # index.saturating_sub(CACHE_PAGE_SIZE / 2).
      def page_offset(index) = [index - (CACHE_PAGE_SIZE / 2), 0].max

      def virtual_do_get_n_items = row_count

      def virtual_do_get_item_type = RowObject.gtype

      # nil past the end, which is the None upstream's item returns — and
      # which Gtk::SingleSelection and the drive both read as "no row".
      def virtual_do_get_item(index)
        if index < row_count
          if cached_rows.key?(index)
            cached_rows[index]
          else
            cache_page(index)[index]
          end
        end
      end

      private

        # One page in, everything outside the guard out. A page that cannot be
        # read leaves the cache as it was, so the miss stays a miss and item
        # answers nil — upstream's `.ok()?`.
        def cache_page(index)
          page_offset(index).then do |offset|
            database.page(table, offset: offset, limit: CACHE_PAGE_SIZE)
              .each_with_index do |row, position|
                cached_rows[offset + position] = RowObject.new(row)
              end

            evict_beyond(index)
          end

          cached_rows
        rescue Database::Error, SQLite3::Exception
          cached_rows
        end

        def evict_beyond(index)
          [index - GUARD_RADIUS, 0].max.then do |low|
            (index + GUARD_RADIUS).then do |high|
              cached_rows.delete_if { |cached, _| cached < low || cached > high }
            end
          end
        end
    end
  end
end
