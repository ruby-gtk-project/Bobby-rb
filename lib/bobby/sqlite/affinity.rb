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

      # U+2014 "Em Dash". Upstream's Display for a value-less NULL or NUMERIC.
      EM_DASH = '—'

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

        # Wraps one value as the sqlite3 gem hands it back, which is upstream's
        # match on rusqlite's ValueRef: Null, Integer, Real, Text, Blob.
        #
        # The gem has no distinct class for a blob read out of a row — both
        # SQLITE_TEXT and SQLITE_BLOB come back as String, and SQLite3::Blob is
        # a write-side wrapper that only ever appears in a value the caller
        # built. What separates them is the encoding the gem stamps on the
        # string: a text column arrives in the database's encoding (UTF-8), a
        # blob arrives as ASCII-8BIT. So the encoding is what is tested, with
        # SQLite3::Blob accepted too for a value that was constructed rather
        # than read.
        def from_value(value)
          case value
          when nil then new(type: NULL)
          when Integer then new(type: INTEGER, value: value)
          when Float then new(type: REAL, value: value)
          when String then from_string(value)
          else new(type: TEXT, value: value.to_s)
          end
        end

        def from_string(string)
          if blob?(string)
            blob(string)
          else
            new(type: TEXT, value: lossy_utf8(string))
          end
        end

        def blob?(string)
          string.is_a?(SQLite3::Blob) || string.encoding == Encoding::BINARY
        end

        # Upstream reads a text value with String::from_utf8_lossy, so bytes
        # that are not valid UTF-8 become U+FFFD. Ruby needs the same: a
        # string that claims UTF-8 but holds invalid bytes raises as soon as
        # anything in GTK reads it.
        def lossy_utf8(string)
          string.dup.force_encoding(Encoding::UTF_8).scrub
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
        when NULL then EM_DASH
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
            EM_DASH
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
