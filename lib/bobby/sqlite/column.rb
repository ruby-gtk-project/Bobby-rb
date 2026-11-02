# frozen_string_literal: true

require_relative 'affinity'

module Bobby
  module Sqlite
    # Column is one column of a table or view.
    #
    # Ported from upstream's src/bobby/sqlite/column.rs, including its
    # Database#columns, which reads PRAGMA table_info. #unique is always
    # false. Upstream's is always false too — column.rs:36 is `let unique =
    # false; // TODO`. Neither app reads PRAGMA index_list, which is the
    # pragma that would answer whether a column is unique.
    #
    # Column.index is upstream's `Column::default()`, inserted at position 0
    # by the content widget to reserve a column for the row numbers.
    class Column
      INFO_COLUMNS = {
        id:          0,
        name:        1,
        type:        2,
        not_null:    3,
        default:     4,
        primary_key: 5,
      }.freeze

      class << self
        # Upstream's Database#columns.
        def all(database, table)
          database.connection.execute("PRAGMA table_info(#{table.name});").map do |row|
            from_info_row(row)
          end
        end

        # The reserved row-number column: no name, no affinity, no key.
        def index = new

        private

          def from_info_row(row)
            new(
              id:          row[INFO_COLUMNS[:id]].to_i,
              name:        row[INFO_COLUMNS[:name]].to_s,
              affinity:    Affinity.parse(row[INFO_COLUMNS[:type]]),
              not_null:    flag(row[INFO_COLUMNS[:not_null]]),
              default:     row[INFO_COLUMNS[:default]],
              primary_key: flag(row[INFO_COLUMNS[:primary_key]]),
            )
          end

          def flag(value) = !value.to_i.zero?
      end

      attr_reader :id, :name, :affinity, :primary_key, :not_null, :default, :unique

      def initialize(id: 0, name: '', affinity: Affinity.new, primary_key: false,
        not_null: false, default: nil)
        @id = id
        @name = name
        @affinity = affinity
        @primary_key = primary_key
        @not_null = not_null
        @default = default
        @unique = false
      end

      def primary_key? = primary_key

      def not_null? = not_null
    end

    # ColumnSeparator is what joins a row's cells when it is copied.
    #
    # Ported from the ColumnSeparator enum in upstream's
    # src/bobby/sqlite/column.rs, whose FromStr accepts both the GSettings
    # value ("tabs") and the character itself ("\t"). Markdown has no single
    # separator: Row#format_with wraps the whole row in pipes instead, which
    # is why its entry here is nil.
    module ColumnSeparator
      TABS = :tabs
      SPACES = :spaces
      COMMAS = :commas
      MARKDOWN = :markdown

      DEFAULT = TABS

      CHARACTERS = {
        TABS     => "\t",
        SPACES   => ' ',
        COMMAS   => ',',
        MARKDOWN => nil,
      }.freeze

      ALIASES = {
        'tabs'     => TABS,
        "\t"       => TABS,
        'spaces'   => SPACES,
        ' '        => SPACES,
        'commas'   => COMMAS,
        ','        => COMMAS,
        'markdown' => MARKDOWN,
      }.freeze

      class << self
        # nil for anything unrecognised, which is upstream's Err; callers fall
        # back to DEFAULT exactly as upstream's unwrap_or_default does.
        def parse(string) = ALIASES[string.to_s]

        def character(separator) = CHARACTERS[separator]
      end
    end
  end
end
