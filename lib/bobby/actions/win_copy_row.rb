# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'adwaita'

require_relative '../settings'
require_relative '../sqlite/column'
require_relative '../util'

module Bobby
  module Actions
    # win.copy-row copies the selected row to the clipboard.
    #
    # Ported from upstream's src/gtk/actions/win_copy_row.rs. The cells are
    # joined with whatever the column-separator preference says, and the toast
    # names the row by its one-based number so it matches the index column.
    #
    # Earlier toasts are dismissed first: holding Ctrl+C down otherwise
    # queues one toast per repeat and they then play out one after the other.
    class WinCopyRow
      NAME = 'copy-row'
      ACCELS = ['<Primary>c'].freeze
      TIMEOUT = 2

      def initialize(window, settings: Settings.instance)
        @window = window
        @settings = settings
      end

      attr_reader :window, :settings

      def build
        action.tap do |a|
          window.application.set_accels_for_action("win.#{NAME}", ACCELS)
          a.signal_connect('activate') { copy }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      private

        def copy
          window.content.then do |content|
            unless content.nil?
              copy_row(content, content.selected_position)
            end
          end
        end

        def copy_row(content, position)
          content.row_at(position).then do |row|
            unless row.nil?
              Util.copy_to_clipboard(row.format_with(separator))
              announce(position + 1)
            end
          end
        end

        def separator = settings.column_separator || Sqlite::ColumnSeparator::DEFAULT

        def announce(row_number)
          window.overlay.tap do |overlay|
            overlay.dismiss_all
            overlay.add_toast(toast("Row #{row_number} copied to clipboard"))
          end
        end

        def toast(title)
          Adwaita::Toast.new(title).tap do |t|
            t.timeout = TIMEOUT
          end
        end
    end
  end
end
