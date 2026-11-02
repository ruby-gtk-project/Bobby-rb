# frozen_string_literal: true

require 'adwaita'

require_relative '../app'

module Bobby
  # AboutDialog credits the app.
  #
  # Ported from upstream's src/gtk/dialogs/about.rs. Upstream leaves a TODO
  # about using AboutDialog::from_appdata() inside Flatpak, where the
  # metainfo file is on disk; the fields below are the ones it sets by hand.
  class AboutDialog < Adwaita::AboutDialog
    DEVELOPER = 'Hylke Bons'
    COPYRIGHT = 'Copyright © 2025–2026  Hylke Bons'

    def build
      tap do |dialog|
        dialog.application_icon = App::ID
        dialog.application_name = App::NAME
        dialog.developer_name = DEVELOPER
        dialog.version = Rb::VERSION
        dialog.website = App::HOMEPAGE
        dialog.issue_url = App::ISSUE_URL
        dialog.copyright = COPYRIGHT
        dialog.license_type = Gtk::License::GPL_3_0
      end
    end
  end
end
