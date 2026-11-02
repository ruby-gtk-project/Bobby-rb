# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative 'sqlite/column'
require_relative 'sqlite/row'

module Bobby
  # Settings is the application's GSettings.
  #
  # Ported from upstream's data/studio.planetpeanut.Bobby.gschema.xml, which
  # declares four keys: row-numbers (b, true), row-order (s, one of
  # newest-first or oldest-first), column-separator (s, one of tabs, spaces,
  # commas or markdown) and monospace-font (b, false). The schema file itself
  # is carried over unchanged, under data/.
  #
  # Upstream builds a fresh gio::Settings at every call site and marks each
  # one for consolidation; here there is one object, reached as
  # Settings.instance, so the change handlers and the preference bindings all
  # talk to the same GSettings.
  #
  # Upstream also notes in src/app.rs that GSETTINGS_SCHEMA_DIR should point
  # at ./data when it is unset, without doing it. That is done here, so a
  # checkout runs against the compiled schema in data/ without installing
  # anything. The other branch — leaving an already-set GSETTINGS_SCHEMA_DIR
  # alone, which is what a Flatpak would set — has never run: the port has no
  # Flatpak manifest, and the checkout branch is the only one taken. See
  # FINDINGS.md.
  class Settings
    SCHEMA_ID = 'studio.planetpeanut.Bobby'
    SCHEMA_DIR = File.expand_path('../../data', __dir__)

    ROW_NUMBERS = 'row-numbers'
    ROW_ORDER = 'row-order'
    COLUMN_SEPARATOR = 'column-separator'
    MONOSPACE_FONT = 'monospace-font'

    KEYS = [ROW_NUMBERS, ROW_ORDER, COLUMN_SEPARATOR, MONOSPACE_FONT].freeze

    # The <choices> of the two string keys, in schema order. Upstream reads
    # them back out of the schema through SettingsSchemaSource so that the
    # combo rows and the stored values cannot drift apart; the port keeps them
    # beside the schema instead, where the same file this class documents is
    # the thing to keep them in step with.
    CHOICES = {
      ROW_ORDER        => Sqlite::RowOrder::SETTINGS_VALUES.keys.freeze,
      COLUMN_SEPARATOR => %w[tabs spaces commas markdown].freeze,
    }.freeze

    class << self
      def instance = @instance ||= new

      # The GSETTINGS_SCHEMA_DIR default upstream describes but never sets.
      def install_schema_dir
        if !ENV.key?('GSETTINGS_SCHEMA_DIR') && File.exist?(File.join(SCHEMA_DIR, 'gschemas.compiled'))
          ENV['GSETTINGS_SCHEMA_DIR'] = SCHEMA_DIR
        end
      end
    end

    def initialize
      self.class.install_schema_dir
    end

    def gio = @gio ||= Gio::Settings.new(SCHEMA_ID)

    def row_numbers? = gio.get_boolean(ROW_NUMBERS)

    def monospace_font? = gio.get_boolean(MONOSPACE_FONT)

    # nil for a value the schema does not know, which is the None upstream's
    # row_order_from_settings returns and which leaves Database on its own
    # default.
    def row_order = Sqlite::RowOrder.from_settings(gio.get_string(ROW_ORDER))

    def column_separator = Sqlite::ColumnSeparator.parse(gio.get_string(COLUMN_SEPARATOR))

    def choices(key) = CHOICES.fetch(key, [])

    def value_at(key, index) = choices(key)[index]

    def index_of(key, value) = choices(key).index(value)

    def selected_index(key) = index_of(key, gio.get_string(key))

    def set_string(key, value) = gio.set_string(key, value)

    # Two-way binding for the switch rows in the preferences dialog.
    def bind(key, object, property)
      gio.bind(
        key,
        object,
        property,
        :default,
      )
    end

    def connect_changed(key, &block)
      gio.signal_connect("changed::#{key}", &block)
    end
  end
end
