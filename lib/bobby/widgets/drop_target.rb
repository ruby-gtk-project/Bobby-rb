# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Widgets
    # DropTarget accepts database files dropped onto a window.
    #
    # Ported from upstream's src/gtk/widgets/drop_target.rs. A drop of a
    # Gdk::FileList is handed straight to Gio::Application#open, which is the
    # same entry point the command line and the file dialog use, so a dropped
    # file is opened by exactly the same code path.
    #
    # The handler answers true: the drop is always accepted, as upstream's is,
    # and a file that turns out not to be a database is reported by the
    # window's error state rather than by refusing the drop.
    class DropTarget
      def initialize(application) = @application = application

      attr_reader :application

      def build
        controller.tap do |target|
          target.signal_connect('drop') do |_, value, _x, _y|
            drop(value)
            true
          end
        end
      end

      def controller
        @controller ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)
      end

      private

        def drop(value)
          if value.is_a?(Gdk::FileList)
            application.open(value.files, '')
          end
        end
    end
  end
end
