# frozen_string_literal: true

require 'sqlite3'

module Bobby
  module Sqlite
    # Affinity is one SQLite value, together with the type affinity it was
    # read or declared under.
    #
    # Ported from upstream's src/bobby/sqlite/affinity.rs, where it is an enum
    # whose variants carry the value: NUMERIC(Option<String>),
    # INTEGER(Option<i64>), REAL(Option<f64>), TEXT(Option<String>),
    # BLOB(Option<i32>, Option<String>) and NULL. Ruby has no payload-carrying
    # enum, so the variant is a symbol in #type and the payload lives in
    # #value, #length and #preview.
    #
    # Two things make it: .parse, which reads a column's declared type out of
    # PRAGMA table_info and yields a valueless affinity, and .from_value,
    # which wraps a value read out of a row.
    class Affinity
      NUMERIC = :numeric
      INTEGER = :integer
      REAL = :real
      TEXT = :text
      BLOB = :blob
      NULL = :null

      TYPES = [NUMERIC, INTEGER, REAL, TEXT, BLOB, NULL].freeze

      # Upstream's Display for a value-less NULL or NUMERIC.
      PLACEHOLDER = '—'

      # Upstream's Display catch-all: a variant that should carry a value but
      # does not, which only happens for a declared-but-unread column.
      UNKNOWN = '???'

      # How many leading bytes of a blob the hex preview shows.
      PREVIEW_LENGTH = 8

      attr_reader :type, :value, :length, :preview

      class << self
        # Upstream's FromStr: the declared type is upper-cased and truncated at
        # the first "(" so that "VARCHAR(255)" is read as "VARCHAR", then
        # matched on substrings exactly as the SQLite docs describe. An empty
        # declaration (a view column, or a rowid alias) is BLOB.
        def parse(declaration)
          declaration.to_s.split('(').first.to_s.upcase.then do |name|
            new(type: type_for_declaration(name))
          end
        end

        # Wraps one value as the sqlite3 gem hands it back. SQLite3::Blob is a
        # String subclass, so it has to be tested before String.
        def from_value(value)
          case value
          when nil then new(type: NULL)
          when Integer then new(type: INTEGER, value: value)
          when Float then new(type: REAL, value: value)
          when SQLite3::Blob then blob(value)
          else new(type: TEXT, value: value.to_s)
          end
        end

        def blob(bytes)
          new(
            type:    BLOB,
            length:  bytes.bytesize,
            preview: hex_preview(bytes, PREVIEW_LENGTH),
          )
        end

        # "DE AD BE EF", upstream's hex_preview.
        def hex_preview(bytes, length)
          bytes.unpack('C*').take(length).map { |byte| format('%02X', byte) }.join(' ')
        end

        private

          def type_for_declaration(name)
            case name
            when /INT/ then INTEGER
            when /TEXT|CHAR|CLOB/ then TEXT
            when /BLOB/, '' then BLOB
            when /REAL|FLOA|DOUB/ then REAL
            else NUMERIC
            end
          end
      end

      def initialize(type: NULL, value: nil, length: nil, preview: nil)
        @type = type
        @value = value
        @length = length
        @preview = preview
      end

      # Upstream's to_type_string.
      def type_string = type.to_s.upcase

      # Upstream's Display. A blob shows its size rather than its bytes; a
      # value-less NULL or NUMERIC shows the em dash; anything else that is
      # missing its value shows "???".
      def to_s
        case type
        when BLOB then blob_to_s
        when NULL then PLACEHOLDER
        when NUMERIC then numeric_to_s
        else value_to_s
        end
      end

      # What the cell's tooltip says: the affinity's name and the value behind
      # it. Upstream assembles this in src/gtk/widgets/item.rs; it is pure
      # value formatting, so it sits with the value here.
      def tooltip
        case type
        when NULL then 'NULL'
        when BLOB then blob_tooltip
        when NUMERIC then numeric_tooltip
        else typed_tooltip
        end
      end

      # The cells upstream dims: a NULL, a NUMERIC that came back empty, and
      # every blob, whose text is a byte count rather than its contents.
      def dimmed? = type == NULL || type == BLOB || (type == NUMERIC && value.nil?)

      def ==(other)
        other.is_a?(Affinity) &&
          other.type == type &&
          other.value == value &&
          other.length == length
      end
      alias eql? ==

      def hash = [type, value, length].hash

      private

        def blob_to_s
          if length.nil?
            UNKNOWN
          else
            "#{length} BYTES"
          end
        end

        def numeric_to_s
          if value.nil?
            PLACEHOLDER
          else
            value.to_s
          end
        end

        def value_to_s
          if value.nil?
            UNKNOWN
          else
            value.to_s
          end
        end

        def blob_tooltip
          if preview.nil?
            "#{self} NULL"
          else
            "#{type_string} #{preview} …"
          end
        end

        def numeric_tooltip
          if value.nil?
            'NULL'
          else
            "#{type_string} #{value}"
          end
        end

        def typed_tooltip
          if value.nil?
            "#{self} NULL"
          else
            "#{type_string} #{value}"
          end
        end
    end
  end
end
