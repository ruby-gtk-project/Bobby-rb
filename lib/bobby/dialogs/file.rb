# frozen_string_literal: true

require 'gtk4'

require_relative '../log'

module Bobby
  # FileDialog is the "Open..." file chooser.
  #
  # Ported from upstream's src/gtk/dialogs/file.rs: open_multiple, behind two
  # filters — the SQLite extensions and MIME types, then everything.
  #
  # Upstream walks the returned list model and calls window_handle_open on
  # each file; the port hands the whole list to Gio::Application#open, which
  # is the entry point the command line and a drag-and-drop already use, so
  # all three arrive at the same place.
  class FileDialog
    SQLITE_FILTER_NAME = 'SQLite Databases'
    SQLITE_MIME_TYPES = %w[application/x-sqlite3 application/vnd-sqlite3].freeze
    SQLITE_PATTERNS = %w[*.db *.db3 *.sqlite *.sqlite3].freeze

    ALL_FILTER_NAME = 'All Files'
    ALL_PATTERN = '*'

    def initialize(application) = @application = application

    attr_reader :application

    def build = dialog

    def present(parent)
      dialog.open_multiple(parent, nil) do |_, result|
        open_files(dialog.open_multiple_finish(result))
      rescue GLib::Error => e
        Log.error("Could not handle file(s): #{e.message}")
      end
    end

    def dialog
      @dialog ||= Gtk::FileDialog.new.tap do |d|
        d.filters = filters
        d.modal = true
      end
    end

    def filters
      @filters ||= Gio::ListStore.new(Gtk::FileFilter).tap do |list|
        list.append(sqlite_filter)
        list.append(all_filter)
      end
    end

    def sqlite_filter
      @sqlite_filter ||= Gtk::FileFilter.new.tap do |filter|
        filter.name = SQLITE_FILTER_NAME
        SQLITE_MIME_TYPES.each { |type| filter.add_mime_type(type) }
        SQLITE_PATTERNS.each { |pattern| filter.add_pattern(pattern) }
      end
    end

    def all_filter
      @all_filter ||= Gtk::FileFilter.new.tap do |filter|
        filter.name = ALL_FILTER_NAME
        filter.add_pattern(ALL_PATTERN)
      end
    end

    private

      def open_files(files)
        files.to_a.then do |list|
          if list.any?
            application.open(list, '')
          end
        end
      end
  end
end
