# frozen_string_literal: true

require "bobby/sqlite/affinity"

# Ported from upstream's src/bobby/tests/sqlite/test_sqlite_affinity.rs,
# which asserts that every variant reports its own SQLite type name. The port
# covers the two other halves of the same class while it is here: the declared
# type parsing the type names come from, and the Display the cells render.
RSpec.describe Bobby::Sqlite::Affinity do
  describe "#type_string" do
    it "names every affinity" do
      expect(
        [
          described_class.new(type: described_class::NUMERIC).type_string,
          described_class.new(type: described_class::INTEGER).type_string,
          described_class.new(type: described_class::REAL).type_string,
          described_class.new(type: described_class::TEXT).type_string,
          described_class.new(type: described_class::BLOB).type_string,
          described_class.new(type: described_class::NULL).type_string,
        ],
      ).to eq(%w[NUMERIC INTEGER REAL TEXT BLOB NULL])
    end
  end

  describe ".parse" do
    it "reads INT anywhere in the declaration as INTEGER" do
      expect(described_class.parse("BIGINT").type).to eq(described_class::INTEGER)
    end

    it "truncates a declaration at its first parenthesis" do
      expect(described_class.parse("VARCHAR(255)").type).to eq(described_class::TEXT)
    end

    it "reads CLOB as TEXT" do
      expect(described_class.parse("CLOB").type).to eq(described_class::TEXT)
    end

    it "reads DOUB and FLOA as REAL" do
      expect(
        [
          described_class.parse("DOUBLE").type,
          described_class.parse("FLOAT").type,
        ],
      ).to eq([described_class::REAL, described_class::REAL])
    end

    # The INT test runs before the FLOA test, in both apps, because
    # https://www.sqlite.org/datatype3.html orders the rules that way. "POINT"
    # contains "INT", so SQLite itself gives FLOATING POINT integer affinity.
    it "lets INT win over FLOA in FLOATING POINT" do
      expect(described_class.parse("FLOATING POINT").type).to eq(described_class::INTEGER)
    end

    it "reads an empty declaration as BLOB" do
      expect(described_class.parse("").type).to eq(described_class::BLOB)
    end

    it "falls back to NUMERIC" do
      expect(described_class.parse("DECIMAL").type).to eq(described_class::NUMERIC)
    end
  end

  describe ".from_value" do
    it "wraps nil as NULL" do
      expect(described_class.from_value(nil).type).to eq(described_class::NULL)
    end

    it "wraps an integer" do
      expect(described_class.from_value(42).value).to eq(42)
    end

    it "wraps a blob with its length and a hex preview" do
      described_class.from_value(SQLite3::Blob.new("\xDE\xAD\xBE\xEF")).then do |affinity|
        expect([affinity.type, affinity.length, affinity.preview])
          .to eq([described_class::BLOB, 4, "DE AD BE EF"])
      end
    end

    # The read path is the one the app actually uses, and it hands back no
    # SQLite3::Blob: both SQLITE_TEXT and SQLITE_BLOB arrive as String, told
    # apart only by the encoding the gem stamps on them. These examples read
    # the values out of a real database so that the arm under test is the arm
    # the ColumnView binds.
    context "with values read out of a database" do
      let(:row) do
        SQLite3::Database.new(":memory:").then do |db|
          db.execute("CREATE TABLE t (a BLOB, b TEXT, c REAL, d INTEGER, e TEXT)")
          db.execute("INSERT INTO t VALUES (X'DEADBEEF', 'Ada', 1.5, 7, NULL)")
          db.execute("SELECT * FROM t").first
        end
      end

      let(:cells) { row.map { |value| described_class.from_value(value) } }

      it "reads a blob column as BLOB" do
        expect([cells[0].type, cells[0].length, cells[0].preview])
          .to eq([described_class::BLOB, 4, "DE AD BE EF"])
      end

      it "shows a blob's byte count rather than its bytes" do
        expect(cells[0].to_s).to eq("4 BYTES")
      end

      it "dims a blob" do
        expect(cells[0].dimmed?).to be(true)
      end

      it "reads the other four columns as themselves" do
        expect(cells.drop(1).map(&:type)).to eq(
          [
            described_class::TEXT,
            described_class::REAL,
            described_class::INTEGER,
            described_class::NULL,
          ],
        )
      end

      it "leaves a text value undimmed" do
        expect([cells[1].to_s, cells[1].dimmed?]).to eq(["Ada", false])
      end
    end

    it "replaces invalid bytes in a text value rather than carrying them" do
      SQLite3::Database.new(":memory:").then do |db|
        db.execute("CREATE TABLE t (a TEXT)")
        db.execute("INSERT INTO t VALUES (CAST(X'41C341' AS TEXT))")

        described_class.from_value(db.execute("SELECT a FROM t").first.first).then do |affinity|
          expect([affinity.type, affinity.to_s.valid_encoding?]).to eq([described_class::TEXT, true])
        end
      end
    end
  end

  describe "#to_s" do
    it "shows an em dash for NULL" do
      expect(described_class.new(type: described_class::NULL).to_s).to eq("—")
    end

    it "shows an em dash for a value-less NUMERIC" do
      expect(described_class.new(type: described_class::NUMERIC).to_s).to eq("—")
    end

    it "shows a blob's size" do
      expect(described_class.new(type: described_class::BLOB, length: 12).to_s).to eq("12 BYTES")
    end

    it "shows ??? for a variant that lost its value" do
      expect(described_class.new(type: described_class::TEXT).to_s).to eq("???")
    end

    # Upstream renders a REAL with `f.to_string()`, which is Rust's
    # `impl Display for f64`: the shortest decimal that reads back as the same
    # f64, written positionally, with no trailing ".0" and never in exponent
    # notation. Ruby's Float#to_s does the trailing ".0" and does use an
    # exponent, so a column of prices or ids that SQLite stored as REAL would
    # otherwise read differently in the two apps — in the cell, in the tooltip
    # and on the clipboard, which all go through this one method.
    #
    # The values are read back out of a real database rather than constructed,
    # because what the app renders is whatever the sqlite3 gem hands back.
    context "with a REAL read out of a database" do
      def stored(literal)
        SQLite3::Database.new(":memory:").then do |db|
          db.execute("CREATE TABLE t (a REAL)")
          db.execute("INSERT INTO t VALUES (#{literal})")
          described_class.from_value(db.execute("SELECT a FROM t").first.first)
        end
      end

      it "drops the trailing .0 of an integral value" do
        expect(stored("1.0").to_s).to eq("1")
      end

      it "keeps the digits of a fractional value" do
        expect(stored("1.5").to_s).to eq("1.5")
      end

      it "writes a very large value in full rather than as an exponent" do
        expect(stored("1e300").to_s).to eq("1#{'0' * 300}")
      end

      it "writes a very small value in full rather than as an exponent" do
        expect(stored("1e-300").to_s).to eq("0.#{'0' * 299}1")
      end

      it "names the type beside the same text in the tooltip" do
        expect(stored("1.0").tooltip).to eq("REAL 1")
      end
    end
  end

  describe "#dimmed?" do
    it "dims NULLs, blobs and value-less NUMERICs" do
      expect(
        [
          described_class.new(type: described_class::NULL).dimmed?,
          described_class.new(type: described_class::BLOB, length: 1).dimmed?,
          described_class.new(type: described_class::NUMERIC).dimmed?,
          described_class.new(type: described_class::TEXT, value: "x").dimmed?,
        ],
      ).to eq([true, true, true, false])
    end
  end

  describe "#tooltip" do
    it "names the type beside the value" do
      expect(described_class.from_value(42).tooltip).to eq("INTEGER 42")
    end

    it "says NULL for a NULL" do
      expect(described_class.from_value(nil).tooltip).to eq("NULL")
    end

    it "shows a blob's preview" do
      expect(described_class.from_value(SQLite3::Blob.new("\x01\x02")).tooltip).to eq("BLOB 01 02 …")
    end
  end
end
