# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative 'log'

module Bobby
  # Util is what is left of upstream's src/gtk/util.rs once the port's widget
  # accessors have taken over.
  #
  # Upstream's widget_by_name walks the whole widget tree looking for a child
  # whose name matches, and find_column_view walks it looking for a
  # ColumnView; both are marked for replacement upstream and both exist only
  # because the window is built by free functions that keep no references to
  # what they made. The port's Window and Content objects hold their widgets
  # in memoized accessors, so there is nothing to search for and neither
  # function is ported.
  #
  # copy_to_clipboard survives, with one binding difference: gtk-rs offers
  # Clipboard::set_text, which ruby-gnome does not wrap. Gdk::Clipboard's
  # setter is #set, which takes the value and infers the content type from it,
  # so a String becomes a text/plain;charset=utf-8 provider — the same content
  # upstream's set_text installs.
  module Util
    class << self
      def copy_to_clipboard(text)
        Gdk::Display.default.then do |display|
          if display.nil?
            Log.error('Missing Display')
          else
            display.clipboard.set(text)
          end
        end
      end
    end
  end
end
