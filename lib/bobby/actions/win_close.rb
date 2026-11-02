# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Actions
    # win.close closes this window.
    #
    # Ported from upstream's src/gtk/actions/win_close.rs, whose handler also
    # carries a TODO about dropping the database from memory; the port closes
    # the connection there, which is the thing that TODO is about.
    class WinClose
      NAME = 'close'
      ACCELS = ['<Primary>w'].freeze

      def initialize(window) = @window = window

      attr_reader :window

      def build
        action.tap do |a|
          window.application.set_accels_for_action("win.#{NAME}", ACCELS)
          a.signal_connect('activate') { window.close }
        end
      end

      def action = @action ||= Gio::SimpleAction.new(NAME, nil)
    end
  end
end
