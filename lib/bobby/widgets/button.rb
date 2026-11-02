# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Widgets
    # OpenButton is the pill in the middle of the empty and error status
    # pages.
    #
    # Ported from upstream's src/gtk/widgets/button.rs. Upstream connects
    # "clicked" and walks window -> application to activate "open" by hand;
    # setting the action name instead lets GTK route it, and it disables the
    # button automatically if the action is ever missing.
    class OpenButton
      LABEL = 'Open...'

      def build = button

      def button
        @button ||= Gtk::Button.new.tap do |btn|
          btn.label = LABEL
          btn.add_css_class('pill')
          btn.add_css_class('suggested-action')
          btn.halign = :center
          btn.action_name = 'app.open'
        end
      end
    end
  end
end
