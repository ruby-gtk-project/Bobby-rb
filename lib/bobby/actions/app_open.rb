# frozen_string_literal: true

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

      def initialize(application) = @application = application

      attr_reader :application

      def build
        action.tap do |a|
          application.set_accels_for_action("app.#{NAME}", ACCELS)
          a.signal_connect('activate') { present }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      def dialog = @dialog ||= FileDialog.new(application)

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
