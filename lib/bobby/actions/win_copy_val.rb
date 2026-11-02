# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'adwaita'

require_relative '../util'

module Bobby
  module Actions
    # win.copy-val copies one cell to the clipboard.
    #
    # Ported from upstream's src/gtk/actions/win_copy_val.rs. The target is a
    # string, "row:column", which the context menu builds when it works out
    # which cell was right-clicked.
    #
    # The toast quotes the copied value and asks Pango for tabular figures, so
    # a column of numbers does not jitter. A value of 96 bytes or more gets no
    # toast at all: upstream builds a shorter title for that case and then
    # never shows it, so the long value is copied silently.
    class WinCopyVal
      NAME = 'copy-val'
      TIMEOUT = 2

      # The length upstream stops announcing the value at, in bytes. Upstream
      # tests `selection.len()`, which is a Rust String's byte length and not
      # its character count — fifty accented characters are a hundred bytes
      # and are copied silently.
      MAX_ANNOUNCED = 96

      # The title upstream builds for a value at or past the cutoff, which
      # upstream then never shows: the `if` that picks the title and the `if`
      # that adds the toast test the same condition, so this string is built
      # and dropped on every long copy. It is here for the same reason it is
      # there — so that the day the second `if` goes, both apps say the same
      # thing rather than one of them saying nothing.
      LONG_TITLE = 'Copied to clipboard'

      # ruby-gnome has no binding for g_markup_escape_text, and the toast
      # title is parsed as markup, so a value containing "<" or "&" would
      # otherwise be dropped. Upstream interpolates the value raw.
      MARKUP_ESCAPES = {
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
        "'" => '&apos;',
        '"' => '&quot;',
      }.freeze

      def initialize(window) = @window = window

      attr_reader :window

      def build
        action.tap do |a|
          a.signal_connect('activate') { |_, parameter| copy(parameter.to_s) }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, GLib::VariantType.new('s'))

      private

        def copy(target)
          indexes(target).then do |row_index, cell_index|
            unless row_index.nil?
              copy_cell(row_index, cell_index)
            end
          end
        end

        # "3:1" -> [3, 1]. An unparsable half becomes 0, which is upstream's
        # unwrap_or_default.
        def indexes(target)
          target.split(':', 2).then do |parts|
            if parts.length == 2
              parts.map { |part| Integer(part, exception: false).to_i }
            else
              [nil, nil]
            end
          end
        end

        def copy_cell(row_index, cell_index)
          window.content&.row_at(row_index).then do |row|
            row&.cell(cell_index).then do |cell|
              unless cell.nil?
                Util.copy_to_clipboard(cell.to_s)
                announce(cell.to_s)
              end
            end
          end
        end

        def announce(value)
          title_for(value).then do |title|
            if announced?(value)
              window.overlay.tap do |overlay|
                overlay.dismiss_all
                overlay.add_toast(toast(title))
              end
            end
          end
        end

        def announced?(value) = value.bytesize < MAX_ANNOUNCED

        def title_for(value)
          if announced?(value)
            markup(value)
          else
            LONG_TITLE
          end
        end

        def toast(title)
          Adwaita::Toast.new(title).tap do |t|
            t.timeout = TIMEOUT
          end
        end

        def markup(value)
          "<span font_features='tnum=1'>‘#{escape(value)}’  copied to clipboard</span>"
        end

        def escape(value) = value.gsub(/[&<>'"]/, MARKUP_ESCAPES)
    end
  end
end
