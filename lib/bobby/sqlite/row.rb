# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require_relative 'affinity'
require_relative 'column'

module Bobby
  module Sqlite
    # RowOrder is the direction rows are read in.
    #
    # Ported from the RowOrder enum in upstream's src/bobby/sqlite/row.rs,
    # whose Display is the SQL keyword. Descending is the default: the newest
    # rows of a log-shaped table are the interesting ones.
    module RowOrder
      DESCENDING = :descending
      ASCENDING = :ascending

      DEFAULT = DESCENDING

      KEYWORDS = {
        DESCENDING => 'DESC',
        ASCENDING  => 'ASC',
      }.freeze

      # The GSettings values of the "row-order" key.
      SETTINGS_VALUES = {
        'newest-first' => DESCENDING,
        'oldest-first' => ASCENDING,
      }.freeze

      class << self
        def keyword(order) = KEYWORDS.fetch(order || DEFAULT)

        # nil for an unrecognised value, which is the None upstream's
        # row_order_from_settings returns.
        def from_settings(value) = SETTINGS_VALUES[value.to_s]
      end
    end

    # Row is one row of a table or view: its cells, in column order.
    #
    # Ported from upstream's src/bobby/sqlite/row.rs, including its
    # Database#rows. The query is the one upstream builds: a table with a
    # rowid is read in rowid order from the offset, and a view or WITHOUT
    # ROWID table — neither of which has a rowid to order by — is read with
    # LIMIT/OFFSET instead.
    class Row
      # GTK list models count in u32, which is why upstream caps the limit
      # there rather than at i64.
      MAX_LIMIT = (2**32) - 1

      class << self
        # Upstream's Database#rows.
        def all(database, table, offset: nil, limit: nil)
          sql(
            database,
            table,
            offset.to_i,
            limit || MAX_LIMIT,
          ).then do |query|
            database.connection.execute(query).map { |values| from_values(values) }
          end
        end

        def from_values(values) = new(values.map { |value| Affinity.from_value(value) })

        private

          def sql(database, table, offset, limit)
            if table.row_id?
              <<~SQL
                SELECT *
                FROM #{table.name}
                WHERE rowid >= #{offset}
                ORDER BY rowid #{RowOrder.keyword(database.row_order)}
                LIMIT #{limit};
              SQL
            else
              <<~SQL
                SELECT *
                FROM #{table.name}
                LIMIT #{limit}
                OFFSET #{offset};
              SQL
            end
          end
      end

      attr_reader :cells

      def initialize(cells = []) = @cells = cells

      def cell(index) = cells[index]

      # Upstream's Row#format_with. Markdown is the odd one out: the cells are
      # joined with " | " and the whole row is wrapped in pipes so it pastes
      # into a Markdown table.
      def format_with(separator)
        cells.map(&:to_s).then do |texts|
          if separator == ColumnSeparator::MARKDOWN
            "| #{texts.join(' | ')} |"
          else
            texts.join(ColumnSeparator.character(separator) || ColumnSeparator.character(ColumnSeparator::DEFAULT))
          end
        end
      end
    end
  end
end
