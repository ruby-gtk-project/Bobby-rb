# frozen_string_literal: true

require 'gtk4'

require_relative '../dialogs/shortcuts'

module Bobby
  module Actions
    # app.shortcuts opens the keyboard shortcuts dialog.
    #
    # Ported from upstream's src/gtk/actions/app_shortcuts.rs.
    class AppShortcuts
      NAME = 'shortcuts'
      ACCELS = ['<Primary>question'].freeze

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
              ShortcutsDialog.new.build.present(window)
            end
          end
        end
    end
  end
end
