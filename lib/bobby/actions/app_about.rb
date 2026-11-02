# frozen_string_literal: true

require 'gtk4'

require_relative '../dialogs/about'

module Bobby
  module Actions
    # app.about opens the about dialog over the active window.
    #
    # Ported from upstream's src/gtk/actions/app_about.rs. No accelerator:
    # upstream reaches it from the main menu only.
    class AppAbout
      NAME = 'about'

      def initialize(application) = @application = application

      attr_reader :application

      def build
        action.tap do |a|
          a.signal_connect('activate') { present }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)

      private

        def present
          application.active_window.then do |window|
            unless window.nil?
              AboutDialog.new.build.present(window)
            end
          end
        end
    end
  end
end
