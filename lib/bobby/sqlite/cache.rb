# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

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
    # I did not build lazy paging, so opening a large table reads every row
    # into memory before the window appears and the app no longer scrolls
    # tables of any size. I am an idiot. Upstream:
    # src/bobby/sqlite/cache.rs. Port: #row_objects and #model below.
    #
    # The two alternatives that need no GInterface — a Gtk::SliceListModel
    # over a store replaced as the view scrolls, and repopulating this store
    # from the ScrolledWindow's vertical adjustment — have been run against a
    # real table and neither is lazy paging. FINDINGS.md, under About the
    # bindings, says what each of them actually did.
    class Cache
      def initialize(database, table)
        @database = database
        @table = table
      end

      attr_reader :database, :table

      def row_count = @row_count ||= database.row_count(table)

      # The RowObjects are held here as well as in the store, and that is not
      # redundant. A GLib::Object subclass defined in Ruby keeps its attribute
      # in a Ruby instance variable, and ruby-gnome associates the Ruby half
      # with the GObject only weakly: dropping the last Ruby reference lets the
      # Ruby object be collected while the GObject lives on in the store, and
      # the next read hands back a freshly made RowObject whose #row is nil.
      # The table then renders blank, and with a few hundred rows the bind
      # handler segfaults on the stale object instead. So the cache outlives
      # the store, which is why the content widget holds the cache and not just
      # the model it built. Found by test/drive_bobby.rb; see FINDINGS.md.
      def row_objects
        @row_objects ||= database.rows(table).map { |row| RowObject.new(row) }
      end

      def model
        @model ||= Gio::ListStore.new(RowObject).tap do |store|
          row_objects.each { |object| store.append(object) }
        end
      end
    end
  end
end
