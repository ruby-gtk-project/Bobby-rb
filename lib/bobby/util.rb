# frozen_string_literal: true

require 'gtk4'

require_relative 'log'

module Bobby
  # Util is what is left of upstream's src/gtk/util.rs once the port's widget
  # accessors have taken over.
  #
  # Upstream's widget_by_name walks the whole widget tree looking for a child
  # whose name matches, and find_column_view walks it looking for a
  # ColumnView; both carry a "TODO" and both exist only because the window is
  # built by free functions that keep no references to what they made. The
  # port's Window and Content objects hold their widgets in memoized
  # accessors, so there is nothing to search for and neither function is
  # ported.
  #
  # copy_to_clipboard survives unchanged.
  module Util
    class << self
      def copy_to_clipboard(text)
        Gdk::Display.default.then do |display|
          if display.nil?
            Log.error('Missing Display')
          else
            display.clipboard.set_text(text)
          end
        end
      end
    end
  end
end
