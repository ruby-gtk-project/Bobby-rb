# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Actions
    # app.quit leaves.
    #
    # Ported from upstream's src/gtk/actions/app_quit.rs.
    class AppQuit
      NAME = 'quit'
      ACCELS = ['<Primary>q'].freeze

      def initialize(application) = @application = application

      attr_reader :application

      def build
        action.tap do |a|
          application.set_accels_for_action("app.#{NAME}", ACCELS)
          a.signal_connect('activate') { application.quit }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)
    end
  end
end
