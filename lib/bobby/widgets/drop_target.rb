# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

module Bobby
  module Widgets
    # DropTarget accepts database files dropped onto a window.
    #
    # Ported from upstream's src/gtk/widgets/drop_target.rs. A drop of a
    # Gdk::FileList is handed to the opener — the Application — which is the
    # same entry point the command line and the file dialog use, so a dropped
    # file is opened by exactly the same code path.
    #
    # Upstream hands the list straight to gio::Application::open. ruby-gnome
    # cannot marshal an array of GFile into a C array, so Gio::Application#open
    # raises NotImplementedError ("TODO: in Ruby -> GIArgument(array/C)
    # [interface(interface)](GFile)"). Application#open_files is the body of
    # the handler GIO itself calls for the "open" signal, so calling it
    # directly reaches the same place without the unmarshallable argument.
    #
    # The handler answers true: the drop is always accepted, as upstream's is,
    # and a file that turns out not to be a database is reported by the
    # window's error state rather than by refusing the drop.
    class DropTarget
      def initialize(opener) = @opener = opener

      attr_reader :opener

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
          if value.is_a?(Gdk::FileList) && !opener.nil?
            opener.open_files(value.files)
          end
        end
    end
  end
end
