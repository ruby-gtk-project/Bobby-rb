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
