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
