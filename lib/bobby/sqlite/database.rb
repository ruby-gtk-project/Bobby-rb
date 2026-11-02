# frozen_string_literal: true

require 'sqlite3'

require_relative 'column'
require_relative 'row'
require_relative 'table'

module Bobby
  module Sqlite
    # Database is one open, read-only SQLite file.
    #
    # Ported from upstream's src/bobby/sqlite/database.rs. The connection is
    # opened read-only through SQLite's URI syntax with immutable=1, which
    # tells SQLite the file cannot change underneath it: no WAL recovery, no
    # locking, no writes to the directory. That is what makes it safe to point
    # Bobby at a database another process owns.
    #
    # The journal_mode check is the file-type test. PRAGMA journal_mode is the
    # cheapest statement that has to read the header, so a file that is not a
    # SQLite database — or one that is encrypted — fails it, and the error
    # message carries Pango markup because the window's error state renders
    # the description as markup.
    #
    # Upstream wraps the connection in Rc<RefCell<..>> so clones share it;
    # Ruby objects are references already, so #clone semantics come for free
    # and the wrapper is gone.
    class Database
      # Raised for anything that stops a file being browsed. Upstream returns
      # Box<dyn Error> with the same two messages.
      class Error < StandardError; end

      BUSY_TIMEOUT_MS = 3_000

      # Docs: https://sqlite.org/uri.html#uriimmutable
      IMMUTABLE_QUERY = 'immutable=1'

      OPEN_FLAGS = SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::URI

      NOT_A_DATABASE = 'File is not a <b>SQLite database</b> or encrypted'
      NO_CONNECTION = 'Could not open a database connection'

      class << self
        # Upstream's Database::from_file. Database files to test on can be
        # found at http://2016.padjo.org/tutorials/sqlite-data-starterpacks
        def from_file(file, row_order = nil) = new(file, row_order)
      end

      attr_reader :file, :row_order, :connection

      def initialize(file, row_order = nil)
        @file = file
        @row_order = row_order
        @connection = open_connection
      end

      def path = file.path

      def uri = "#{file.uri}?#{IMMUTABLE_QUERY}"

      # The tables and views the switcher offers.
      def tables = Table.all(self)

      def row_count(table) = Table.row_count(self, table)

      def columns(table) = Column.all(self, table)

      def rows(table, offset: nil, limit: nil)
        Row.all(
          self,
          table,
          offset: offset,
          limit:  limit,
        )
      end

      # Upstream's Database#data_version: the counter SQLite bumps when
      # another connection commits, which is how a changed file is noticed.
      # nil when the pragma cannot be read.
      def data_version
        connection.get_first_value('PRAGMA data_version').then { |value| value&.to_i }
      rescue SQLite3::Exception
        nil
      end

      def close
        unless connection.closed?
          connection.close
        end
      end

      private

        def open_connection
          connect.tap do |connection|
            if journal_mode(connection).nil?
              raise(Error, NOT_A_DATABASE)
            end

            connection.busy_timeout = BUSY_TIMEOUT_MS
            connection.execute('PRAGMA query_only = 1')
            connection.execute('PRAGMA foreign_keys = 1')
          end
        end

        def connect
          SQLite3::Database.new(uri, flags: OPEN_FLAGS)
        rescue SQLite3::Exception, ArgumentError
          raise(Error, NO_CONNECTION)
        end

        # Upstream's Database::journal_mode: Some(mode) for a readable SQLite
        # file, None for anything else.
        def journal_mode(connection)
          connection.get_first_value('PRAGMA journal_mode')
        rescue SQLite3::Exception
          nil
        end
    end
  end
end
