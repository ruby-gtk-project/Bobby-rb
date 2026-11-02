# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'actions/app_about'
require_relative 'actions/app_open'
require_relative 'actions/app_preferences'
require_relative 'actions/app_quit'
require_relative 'actions/app_shortcuts'
require_relative 'app'
require_relative 'cli'
require_relative 'log'
require_relative 'settings'
require_relative 'window'

module Bobby
  # Application is the GTK application: the windows, the app-scope actions and
  # the GSettings watches.
  #
  # Ported from upstream's src/gtk/lib.rs — the `impl Gui for App` that builds
  # the libadwaita Application, connects "open" and "activate", watches three
  # GSettings keys so an open window follows a changed preference, and
  # registers the five app actions. #start is upstream's src/main.rs: the
  # version line on DEBUG, the refusal to run as root, and the CLI options
  # when there is a terminal to print them to.
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
    ROOT_REFUSAL = 'Cannot run as root'

    def initialize(app_info: App.new, settings: Settings.instance)
      @app_info = app_info
      @settings = settings
      @windows = []
    end

    attr_reader :app_info, :settings, :windows

    # Upstream's main(), in order.
    def start(argv = ARGV)
      Log.debug_base(App.version_string)

      if App.runs_as_root?
        Log.error_and_exit(ROOT_REFUSAL)
      end

      if App.runs_in_terminal?
        cli.parse(argv)
      end

      build.run([App::COMMAND, *argv])
    end

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

    def cli = @cli ||= Cli.new(app_info)

    def app_actions
      @app_actions ||= [
        Actions::AppAbout.new(app),
        Actions::AppOpen.new(app),
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
        Gtk::Application.new(App::ID, FLAGS)
      end

      def open_files(files)
        files.each { |file| handle_open(file) }
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
        Window.new(app, settings: settings).tap do |window|
          window.build
          windows << window
          window.window.signal_connect('destroy') { windows.delete(window) }
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
