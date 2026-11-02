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
    # win.reload re-reads the open file.
    #
    # Ported from upstream's src/gtk/actions/win_reload.rs together with the
    # window_reload it calls. The point of it is that nothing visibly moves:
    # the selected table and the scroll offsets are carried across, so a file
    # that changed on disk is re-read in place.
    #
    # An empty window has nothing to reload, which is upstream's early return
    # on the empty-window marker. It is also what the row-order and
    # monospace-font preferences activate to take effect, since both change
    # the query or the cell widgets rather than anything that can be updated
    # in place.
    class WinReload
      NAME = 'reload'
      ACCELS = ['<Primary>r'].freeze

      def initialize(window) = @window = window

      attr_reader :window

      def build
        action.tap do |a|
          window.application.set_accels_for_action("win.#{NAME}", ACCELS)
          a.signal_connect('activate') { reload }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      private

        def reload
          unless window.empty?
            window.reload
          end
        end
    end
  end
end
