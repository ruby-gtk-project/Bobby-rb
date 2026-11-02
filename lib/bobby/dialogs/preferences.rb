# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'adwaita'

require_relative '../settings'

module Bobby
  # PreferencesDialog edits the four GSettings keys.
  #
  # Ported from upstream's src/gtk/dialogs/preferences.rs: one page, a "Rows
  # &amp; Columns" group holding the row-numbers switch, the row-order combo
  # and the column-separator combo, and an "Appearance" group holding the
  # monospace switch.
  #
  # The switches are bound to GSettings, so they need no handler. The combos
  # cannot be: a ComboRow's "selected" is a position and the key is a string,
  # so the position is resolved against the schema's <choices> in both
  # directions — Settings#selected_index on the way in, Settings#value_at on
  # the way out.
  #
  # The group title keeps upstream's escaped ampersand: Adwaita renders these
  # titles as markup.
  class PreferencesDialog < Adwaita::PreferencesDialog
    PAGE_TITLE = 'Preferences'
    PAGE_ICON = 'org.gnome.Settings-system-symbolic'

    ROW_ORDER_CHOICES = ['Newest First', 'Oldest First'].freeze
    COLUMN_SEPARATOR_CHOICES = %w[Tabs Spaces Commas Markdown].freeze
    COLUMN_SEPARATOR_SUBTITLE = 'Used when copying rows to the clipboard'

    def initialize(settings: Settings.instance)
      super()
      @settings = settings
    end

    attr_reader :settings

    def build
      tap do |dialog|
        dialog.add(page)

        page.tap do |p|
          p.add(rows_group)
          p.add(appearance_group)

          rows_group.tap do |group|
            group.add(row_numbers_row)
            group.add(row_order_row)
            group.add(column_separator_row)
          end

          appearance_group.add(monospace_row)
        end

        settings.bind(Settings::ROW_NUMBERS, row_numbers_row, 'active')
        settings.bind(Settings::MONOSPACE_FONT, monospace_row, 'active')

        bind_combo(row_order_row, Settings::ROW_ORDER)
        bind_combo(column_separator_row, Settings::COLUMN_SEPARATOR)
      end
    end

    # Memoized widget methods

    def page
      @page ||= Adwaita::PreferencesPage.new.tap do |p|
        p.title = PAGE_TITLE
        p.icon_name = PAGE_ICON
      end
    end

    def rows_group
      @rows_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Rows &amp; Columns'
      end
    end

    def appearance_group
      @appearance_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Appearance'
      end
    end

    def row_numbers_row
      @row_numbers_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = 'Row Numbers'
      end
    end

    def monospace_row
      @monospace_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = 'Monospace Font'
      end
    end

    def row_order_row
      @row_order_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = 'Row Order'
        row.model = Gtk::StringList.new(ROW_ORDER_CHOICES)
      end
    end

    def column_separator_row
      @column_separator_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = 'Column Separator'
        row.subtitle = COLUMN_SEPARATOR_SUBTITLE
        row.model = Gtk::StringList.new(COLUMN_SEPARATOR_CHOICES)
      end
    end

    private

      def bind_combo(row, key)
        settings.selected_index(key).then do |index|
          unless index.nil?
            row.selected = index
          end
        end

        row.signal_connect('notify::selected') { write_combo(row, key) }
      end

      def write_combo(row, key)
        settings.value_at(key, row.selected).then do |value|
          unless value.nil?
            settings.set_string(key, value)
          end
        end
      end
  end
end
