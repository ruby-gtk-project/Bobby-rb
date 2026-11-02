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

      # Memoized, as AppOpen's file dialog is: an Adwaita dialog can be
      # presented again after it is closed, and holding the one the action
      # opens is what lets anything outside the handler see it.
      def dialog = @dialog ||= ShortcutsDialog.new.build

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
