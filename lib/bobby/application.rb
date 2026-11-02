# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'
require 'adwaita'

require_relative 'actions/app_about'
require_relative 'actions/app_open'
require_relative 'actions/app_preferences'
require_relative 'actions/app_quit'
require_relative 'actions/app_shortcuts'
require_relative 'app'
require_relative 'icons'
require_relative 'log'
require_relative 'preflight'
require_relative 'settings'
require_relative 'window'

module Bobby
  # Application is the GTK application: the windows, the app-scope actions and
  # the GSettings watches.
  #
  # Ported from upstream's src/gtk/lib.rs — the `impl Gui for App` that builds
  # the libadwaita Application, connects "open" and "activate", watches three
  # GSettings keys so an open window follows a changed preference, and
  # registers the five app actions. #start is upstream's src/main.rs: Preflight
  # for the half that runs before a display is needed, then #run_gui.
  #
  # HANDLES_OPEN is what makes "bobby file.db" and a drag-and-drop both arrive
  # at "open" rather than "activate", so every way of opening a file goes
  # through #handle_open.
  #
  # Upstream finds a window again by comparing the path against every
  # window's widget name; the port keeps its own Window objects in #windows
  # and asks them for their #key, which is the same lookup without the tree
  # walk. Windows are dropped from that list when GTK destroys them.
  #
  # Adwaita::Application is broken in the Ruby bindings, so the application
  # object is a Gtk::Application and Adwaita is initialised by hand — the
  # windows and dialogs are Adwaita's regardless.
  class Application
    FLAGS = :handles_open

    NO_LOCAL_PATH = 'Selected file has no local path'

    def initialize(app_info: App.new, settings: Settings.instance)
      @app_info = app_info
      @settings = settings
      @windows = []
    end

    attr_reader :app_info, :settings, :windows

    # Upstream's main(), in order.
    def start(argv = ARGV)
      Preflight.run(argv, app_info: app_info)
      run_gui(argv)
    end

    # Upstream's gui_run(): build the application and hand it the argument
    # vector, program name first, so HANDLES_OPEN turns a file argument into
    # an "open" signal. exe/bobby calls this rather than #start because it has
    # already run the preflight, before the gtk4 gem was loaded.
    def run_gui(argv = ARGV) = build.run([App::COMMAND, *argv])

    def build
      app.tap do |a|
        a.signal_connect('open') { |_, files, _hint| open_files(files) }
        a.signal_connect('activate') { activate }

        app_actions.each { |action| a.add_action(action.build) }

        connect_settings
      end
    end

    def run(argv = []) = app.run(argv)

    def app = @app ||= create_app

    def app_actions
      @app_actions ||= [
        Actions::AppAbout.new(app),
        Actions::AppOpen.new(app, opener: self),
        Actions::AppPreferences.new(app),
        Actions::AppQuit.new(app),
        Actions::AppShortcuts.new(app),
      ]
    end

    # An already-open file is raised rather than opened twice; otherwise the
    # window waiting for a file takes it, and failing that a new one is made.
    def handle_open(file, table_name: nil)
      file.path.then do |path|
        if path.nil?
          Log.error(NO_LOCAL_PATH)
        else
          open_path(path, file, table_name)
        end
      end
    end

    # The body of the handler GIO calls for the "open" signal, which the file
    # dialog and the drop target call directly: Gio::Application#open takes a
    # C array of GFile, which ruby-gnome cannot marshal.
    def open_files(files)
      files.each { |file| handle_open(file) }
    end

    def activate
      app.active_window.then do |existing|
        if existing.nil?
          new_window.present
        else
          existing.present
        end
      end
    end

    private

      def create_app
        Adwaita.init
        Icons.install
        Gtk::Application.new(App::ID, FLAGS)
      end

      def open_path(path, file, table_name)
        window_for(path).then do |existing|
          if existing.nil?
            load_into(target_window, file, table_name)
          else
            existing.present
          end
        end
      end

      def load_into(window, file, table_name)
        window.load(file, table_name: table_name)
        window.present
      end

      def window_for(path) = windows.find { |window| window.key == path }

      def target_window = windows.find(&:empty?) || new_window

      def new_window
        Window.new(app, settings: settings, opener: self).tap do |window|
          window.build
          windows << window
          forget_when_closed(window)
        end
      end

      # Upstream enumerates the application's own window list, which GTK
      # empties as windows close. The port keeps its Window objects, so it has
      # to be told. Both signals are watched because GTK4's gtk_window_close
      # unmaps the window and takes it off the application without destroying
      # it and without emitting "destroy": a destroy handler on its own leaves
      # a window the user closed in the list for ever, and the next file opened
      # would be loaded into it and never seen.
      def forget_when_closed(window)
        window.window.tap do |gtk_window|
          gtk_window.signal_connect('close-request') do
            window.detach_content
            windows.delete(window)
            false
          end

          gtk_window.signal_connect('destroy') do
            window.detach_content
            windows.delete(window)
          end
        end
      end

      # The three keys upstream watches. Row numbers can be toggled in place;
      # the row order and the monospace font cannot, so they reload.
      def connect_settings
        settings.connect_changed(Settings::ROW_NUMBERS) { toggle(:toggle_row_numbers) }
        settings.connect_changed(Settings::ROW_ORDER) { toggle(:toggle_by_reload) }
        settings.connect_changed(Settings::MONOSPACE_FONT) { toggle(:toggle_by_reload) }
      end

      def toggle(message)
        active_window.then do |window|
          unless window.nil?
            window.public_send(message)
          end
        end
      end

      def active_window
        app.active_window.then do |active|
          windows.find { |window| window.window == active }
        end
      end
  end
end
