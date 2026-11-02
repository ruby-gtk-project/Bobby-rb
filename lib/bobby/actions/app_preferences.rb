# frozen_string_literal: true

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

      private

        def present
          application.active_window.then do |window|
            unless window.nil?
              PreferencesDialog.new.build.present(window)
            end
          end
        end
    end
  end
end
