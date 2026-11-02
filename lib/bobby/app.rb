# frozen_string_literal: true

require 'sqlite3'

require_relative 'log'
require_relative 'rb/version'

module Bobby
  # App is the application's identity and the paths it was installed and runs
  # under.
  #
  # Ported from upstream's src/app.rs, whose App struct is built once by
  # App::default() and then carried around. The Cargo environment variables
  # upstream bakes in at compile time become constants here: CARGO_PKG_NAME and
  # CARGO_BIN_NAME are both "bobby", and CARGO_PKG_VERSION is the gem version.
  #
  # Upstream shells out to `id -u` to detect root because that is the shortest
  # path to it from Rust; Ruby has Process.uid, so #runs_as_root? reads it
  # directly rather than forking.
  class App
    ID = 'studio.planetpeanut.Bobby'
    NAME = 'bobby'
    COMMAND = 'bobby'
    HOMEPAGE = 'https://github.com/hbons/Bobby'
    ISSUE_URL = 'https://github.com/hbons/Bobby/issues'

    # Upstream's hardcoded Flatpak prefix.
    PREFIX = '/app'

    attr_reader :id,
      :name,
      :command,
      :icon,
      :version,
      :prefix,
      :desktop_file,
      :appdata_file,
      :app_config_home,
      :app_data_home,
      :app_cache_home

    class << self
      def flatpak? = ENV.key?('FLATPAK_ID')

      # "bobby 0.1.0", with " (Flatpak)" appended inside the sandbox.
      def version_string
        "#{NAME} #{Rb::VERSION}".then do |string|
          if flatpak?
            "#{string} (Flatpak)"
          else
            string
          end
        end
      end

      # Upstream reports rusqlite's bundled SQLite; the port reports the
      # library the sqlite3 gem is linked against.
      def deps = "SQLite #{SQLite3::SQLITE_VERSION}"

      def runs_as_root? = Process.uid.zero?

      # TERM is propagated even in Flatpak, which is why upstream trusts it.
      def runs_in_terminal? = ENV.key?('TERM')
    end

    def initialize
      @id = ID
      @name = NAME
      @command = COMMAND
      @icon = ID
      @version = Rb::VERSION
      @prefix = PREFIX
      # Both of these are upstream's src/app.rs:82-83 unchanged, and both name
      # files that do not exist. PREFIX is '/app', which only exists inside a
      # Flatpak, and the port has no Flatpak manifest. The basenames are wrong
      # upstream too: data/meson.build installs
      # studio.planetpeanut.Bobby.desktop into share/applications and
      # studio.planetpeanut.Bobby.metainfo.xml into share/metainfo, not
      # bobby.desktop and share/appdata/bobby.appdata.xml. Nothing reads
      # either field, which is why neither app has noticed. See FINDINGS.md.
      @desktop_file = File.join(PREFIX, 'share/applications', "#{COMMAND}.desktop")
      @appdata_file = File.join(PREFIX, 'share/appdata', "#{COMMAND}.appdata.xml")
      @app_config_home = File.join(xdg_config_home, COMMAND)
      @app_data_home = File.join(xdg_data_home, COMMAND)
      @app_cache_home = File.join(xdg_cache_home, COMMAND)
    end

    def flatpak? = self.class.flatpak?

    # What upstream's `--env` prints with "{:#?}".
    def to_h
      {
        id:              id,
        name:            name,
        command:         command,
        icon:            icon,
        version:         version,
        is_flatpak:      flatpak?,
        prefix:          prefix,
        desktop_file:    desktop_file,
        appdata_file:    appdata_file,
        app_config_home: app_config_home,
        app_data_home:   app_data_home,
        app_cache_home:  app_cache_home,
      }
    end

    private

      # Upstream leaves with status 255 when HOME is unreadable rather than
      # guessing a home directory.
      def home_dir
        ENV.fetch('HOME') { Log.error_and_exit('Could not read HOME environment variable') }
      end

      # Flatpak sets the XDG variables to ~/.var/app/<APP_ID>/..., so they win
      # over the defaults below whenever they are present.
      def xdg_config_home
        ENV.fetch('XDG_CONFIG_HOME') { File.join(home_dir, '.config') }
      end

      def xdg_data_home
        ENV.fetch('XDG_DATA_HOME') { File.join(home_dir, '.local/share') }
      end

      def xdg_cache_home
        ENV.fetch('XDG_CACHE_HOME') { File.join(home_dir, '.cache') }
      end
  end
end
