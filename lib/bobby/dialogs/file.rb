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
  # each file; the port hands the whole list to the opener — the Application —
  # whose #open_files is the body of the handler GIO calls for the "open"
  # signal, so the command line, a drag-and-drop and this dialog all arrive at
  # the same place.
  #
  # Not Gio::Application#open, which upstream's drop target uses: ruby-gnome
  # cannot marshal an array of GFile into a C array and the call raises
  # NotImplementedError ("TODO: in Ruby -> GIArgument(array/C)
  # [interface(interface)](GFile)").
  class FileDialog
    SQLITE_FILTER_NAME = 'SQLite Databases'
    SQLITE_MIME_TYPES = %w[application/x-sqlite3 application/vnd-sqlite3].freeze
    SQLITE_PATTERNS = %w[*.db *.db3 *.sqlite *.sqlite3].freeze

    ALL_FILTER_NAME = 'All Files'
    ALL_PATTERN = '*'

    def initialize(opener) = @opener = opener

    attr_reader :opener

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
          if list.any? && !opener.nil?
            opener.open_files(list)
          end
        end
      end
  end
end
