# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

module Bobby
  module Sqlite
    # TableName is a validated SQLite identifier.
    #
    # Ported from the TableName newtype in upstream's
    # src/bobby/sqlite/table.rs. Every table name reaches a query by string
    # interpolation — SQLite cannot bind an identifier as a parameter — so the
    # name is validated once, here, and the type is the proof: empty names,
    # the internal sqlite_ tables and anything outside letters, digits and
    # underscore are rejected.
    class TableName
      # Upstream's Default for TableName.
      DEFAULT = 'table'

      VALID = /\A[[:alnum:]_]+\z/

      class << self
        # Upstream's FromStr, which returns Err rather than panicking.
        def parse(string)
          if valid?(string)
            new(string)
          end
        end

        def valid?(string)
          string.to_s.then do |name|
            !name.empty? && !name.start_with?('sqlite_') && name.match?(VALID)
          end
        end
      end

      attr_reader :value

      def initialize(value = DEFAULT) = @value = value

      def to_s = value

      def ==(other) = other.is_a?(TableName) && other.value == value
      alias eql? ==

      def hash = value.hash
    end

    # Table is one table or view in the open database.
    #
    # Ported from upstream's src/bobby/sqlite/table.rs. has_row_id is
    # deliberately three-valued, as it is upstream: true for an ordinary
    # table, false for a WITHOUT ROWID table, and nil for a view, which has no
    # rowid to order by. Database#rows switches its query on it.
    class Table
      # Upstream's query in `impl Database { fn tables }`: every table and
      # view except SQLite's own, with a has_row_id column computed from the
      # stored CREATE statement — 0 for WITHOUT ROWID, 1 for a table, NULL for
      # a view.
      ALL_SQL = <<~SQL
        SELECT name,
          CASE
            WHEN type = 'table' AND sql LIKE '%WITHOUT ROWID%' THEN 0
            WHEN type = 'table' THEN 1
            ELSE NULL
          END AS has_row_id,
          type
        FROM sqlite_master
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
      SQL

      class << self
        # Upstream's Database#tables. A name that fails validation aborts the
        # whole listing, as it does upstream, so the window shows its error
        # state rather than a half-populated switcher.
        def all(database)
          database.connection.execute(ALL_SQL).map { |row| from_row(row) }
        end

        # Upstream's Database#row_count. The table name is interpolated
        # because SQLite cannot bind an identifier; TableName is what makes
        # that safe.
        def row_count(database, table)
          database.connection.get_first_value("SELECT COUNT(*) FROM #{table.name}").to_i
        end

        private

          def from_row(row)
            TableName.parse(row[0]).then do |name|
              if name.nil?
                raise(Database::Error, "Invalid table name: #{row[0]}")
              end

              new(
                name:       name,
                has_row_id: has_row_id(row[1]),
                is_view:    row[2] == 'view',
              )
            end
          end

          # NULL stays nil: a view has no rowid at all.
          def has_row_id(value)
            unless value.nil?
              !value.to_i.zero?
            end
          end
      end

      attr_reader :name, :has_row_id, :is_view

      def initialize(name: TableName.new, has_row_id: nil, is_view: false)
        @name = name
        @has_row_id = has_row_id
        @is_view = is_view
      end

      def to_s = name.to_s

      def view? = is_view

      # Only an ordinary table can be ordered by rowid.
      def row_id? = has_row_id == true

      def ==(other)
        other.is_a?(Table) &&
          other.name == name &&
          other.has_row_id == has_row_id &&
          other.is_view == is_view
      end
      alias eql? ==

      def hash = [name, has_row_id, is_view].hash
    end
  end
end
