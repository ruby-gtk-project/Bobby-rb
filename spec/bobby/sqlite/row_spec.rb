# frozen_string_literal: true

require "sqlite3"

require "bobby/sqlite/row"
require "bobby/sqlite/table"

# Row.all is upstream's Database::rows (src/bobby/sqlite/row.rs). Row.page is
# the port's own second query, and it exists because upstream's pages a rowid
# table by rowid rather than by the index a list model counts in. These
# examples pin both: that Row.all still reads upstream's query, and that
# Row.page answers the row a given index names whichever direction the table
# is read in.
RSpec.describe Bobby::Sqlite::Row do
  # Row.page and Row.all take Database's three readers and nothing else, so a
  # Database — which wants a Gio::File and a GTK stack behind it — is more than
  # these examples need.
  connection_holder = Struct.new(:connection, :row_order)

  def table_for(name, row_id:)
    Bobby::Sqlite::Table.new(
      name:       Bobby::Sqlite::TableName.parse(name),
      has_row_id: row_id,
      is_view:    !row_id,
    )
  end

  let(:connection) do
    SQLite3::Database.new(":memory:").tap do |db|
      db.execute("CREATE TABLE numbers (id INTEGER PRIMARY KEY, label TEXT)")
      db.transaction { 10.times { |n| db.execute("INSERT INTO numbers VALUES (#{n + 1}, 'row #{n + 1}')") } }
      db.execute("CREATE VIEW numbers_view AS SELECT label FROM numbers")
    end
  end

  let(:numbers) { table_for("numbers", row_id: true) }

  describe ".page" do
    it "reads newest first from the index it is given" do
      database = connection_holder.new(connection, Bobby::Sqlite::RowOrder::DESCENDING)

      expect(
        described_class.page(database, numbers, offset: 4, limit: 3)
          .map { |row| row.cell(1).value },
      ).to eq(["row 6", "row 5", "row 4"])
    end

    it "reads oldest first from the same index" do
      database = connection_holder.new(connection, Bobby::Sqlite::RowOrder::ASCENDING)

      expect(
        described_class.page(database, numbers, offset: 4, limit: 3)
          .map { |row| row.cell(1).value },
      ).to eq(["row 5", "row 6", "row 7"])
    end

    it "runs past the end without raising" do
      database = connection_holder.new(connection, nil)

      expect(described_class.page(database, numbers, offset: 9, limit: 256).length).to eq(1)
    end

    it "pages a view by offset too" do
      database = connection_holder.new(connection, nil)
      view = table_for("numbers_view", row_id: false)

      expect(
        described_class.page(database, view, offset: 2, limit: 2)
          .map { |row| row.cell(0).value },
      ).to eq(["row 3", "row 4"])
    end
  end

  describe ".all" do
    # The reason Row.page exists: upstream's offset is a rowid predicate, so
    # read newest-first it answers the top of the table for every offset.
    it "keeps upstream's rowid paging, which does not follow the index" do
      database = connection_holder.new(connection, Bobby::Sqlite::RowOrder::DESCENDING)

      expect(
        described_class.all(database, numbers, offset: 4, limit: 3)
          .map { |row| row.cell(1).value },
      ).to eq(["row 10", "row 9", "row 8"])
    end
  end

  describe "#format_with" do
    it "wraps a row in pipes for Markdown" do
      database = connection_holder.new(connection, Bobby::Sqlite::RowOrder::ASCENDING)

      expect(
        described_class.page(database, numbers, offset: 0, limit: 1)
          .first
          .format_with(Bobby::Sqlite::ColumnSeparator::MARKDOWN),
      ).to eq("| 1 | row 1 |")
    end
  end
end
