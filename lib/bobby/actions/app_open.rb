# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative '../dialogs/file'

module Bobby
  module Actions
    # app.open shows the file chooser.
    #
    # Ported from upstream's src/gtk/actions/app_open.rs. This is the action
    # the pill on the empty and error pages activates.
    class AppOpen
      NAME = 'open'
      ACCELS = ['<Primary>o'].freeze

      def initialize(application, opener: nil)
        @application = application
        @opener = opener
      end

      attr_reader :application, :opener

      def build
        action.tap do |a|
          application.set_accels_for_action("app.#{NAME}", ACCELS)
          a.signal_connect('activate') { present }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      def dialog = @dialog ||= FileDialog.new(opener)

      private

        def present
          application.active_window.then do |window|
            unless window.nil?
              dialog.present(window)
            end
          end
        end
    end
  end
end
