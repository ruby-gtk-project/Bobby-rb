# frozen_string_literal: true

require 'gtk4'

module Bobby
  # Icons puts the app's own icons where GTK will look for them.
  #
  # Stands in for upstream's data/icons/meson.build, which installs
  # data/icons/hicolor into <prefix>/share/icons on `meson install`, so that
  # by the time the app runs XDG_DATA_DIRS already carries them. A gem
  # checkout has no install step, so the two icons the app names by id —
  # studio.planetpeanut.Bobby and studio.planetpeanut.Bobby-symbolic, the
  # second being the icon of the empty state's status page — resolve to GTK's
  # generic broken-image icon instead.
  #
  # Adding the shipped icons directory to the display's icon theme search path
  # is the same registration without the copy: the directory already has the
  # hicolor layout GTK scans for, so both ids resolve from a checkout.
  module Icons
    DIR = File.expand_path('../../data/icons', __dir__)

    class << self
      # Nothing to do without a display — the icon theme is per-display, and
      # the CLI options never open one.
      def install
        Gdk::Display.default.then do |display|
          if !display.nil? && File.directory?(DIR)
            Gtk::IconTheme.get_for_display(display).add_search_path(DIR)
          end
        end
      end
    end
  end
end
