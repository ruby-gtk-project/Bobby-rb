# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

module Bobby
  module Actions
    # win.close closes this window.
    #
    # Ported from upstream's src/gtk/actions/win_close.rs, whose handler also
    # notes that the database should be dropped from memory without doing it;
    # the port closes the connection there, which is that drop.
    class WinClose
      NAME = 'close'
      ACCELS = ['<Primary>w'].freeze

      def initialize(window) = @window = window

      attr_reader :window

      def build
        action.tap do |a|
          window.application.set_accels_for_action("win.#{NAME}", ACCELS)
          a.signal_connect('activate') { window.close }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)
    end
  end
end
