# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

require_relative '../dialogs/preferences'

module Bobby
  module Actions
    # app.preferences opens the preferences dialog over the active window.
    #
    # Ported from upstream's src/gtk/actions/app_preferences.rs.
    class AppPreferences
      NAME = 'preferences'
      ACCELS = ['<Primary>comma'].freeze

      def initialize(application) = @application = application

      attr_reader :application

      def build
        action.tap do |a|
          application.set_accels_for_action("app.#{NAME}", ACCELS)
          a.signal_connect('activate') { present }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      # Memoized, as AppOpen's file dialog is: an Adwaita dialog can be
      # presented again after it is closed, and holding the one the action
      # opens is what lets anything outside the handler see it.
      def dialog = @dialog ||= PreferencesDialog.new.build

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
