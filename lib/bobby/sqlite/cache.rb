# frozen_string_literal: true

require 'gtk4'

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

    # Cache builds the list model the content widget's ColumnView reads.
    #
    # Ported from upstream's src/bobby/sqlite/cache.rs, where
    # DatabaseCacheModel is a custom Gio.ListModel: it answers item(n) by
    # fetching a 256-row page centred on n, caching it in a BTreeMap, and
    # evicting everything further than 256 rows from n so a long scroll does
    # not grow without bound. n_items answers SELECT COUNT(*) once.
    #
    # ruby-gnome cannot implement a GInterface's virtual functions from Ruby,
    # so a custom Gio::ListModel is not available to the port and the lazy
    # paging has nowhere to live. The table is read once, in order, into a
    # Gio::ListStore, which answers the model interface from C. The visible
    # behaviour is identical; the cost is that the whole table is held in
    # memory rather than a window of it.
    #
    # One statement rather than upstream's pages on purpose: upstream's paged
    # query for a rowid table is `WHERE rowid >= offset LIMIT n`, which only
    # lines up with the row index while the rowids are contiguous and start at
    # zero. Reading the table in one go has no offset to get wrong.
    class Cache
      class << self
        def model_for(database, table) = new(database, table).model
      end

      def initialize(database, table)
        @database = database
        @table = table
      end

      attr_reader :database, :table

      def row_count = @row_count ||= database.row_count(table)

      def model
        @model ||= Gio::ListStore.new(RowObject).tap do |store|
          database.rows(table).each { |row| store.append(RowObject.new(row)) }
        end
      end
    end
  end
end
