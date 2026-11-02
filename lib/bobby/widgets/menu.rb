# frozen_string_literal: true

require 'gtk4'

module Bobby
  module Widgets
    # Menu is the hamburger button at the end of the header bar.
    #
    # Ported from upstream's src/gtk/widgets/menu.rs, including the app
    # action it installs on the side: "open-menu", bound to F10, exists only
    # so the keyboard can pop the button open, since a MenuButton has no
    # action of its own.
    #
    # Upstream hands the button a PopoverMenu built from the model; setting
    # the model on the button lets GTK build that popover itself, which is the
    # same widget with one less line.
    class Menu
      ACTION = 'open-menu'
      ACCELS = ['F10'].freeze

      ITEMS = {
        'Preferences'        => 'app.preferences',
        'Keyboard Shortcuts' => 'app.shortcuts',
        'About Bobby'        => 'app.about',
      }.freeze

      def initialize(application) = @application = application

      attr_reader :application

      def build
        button.tap do |btn|
          application.add_action(open_menu_action)
          application.set_accels_for_action("app.#{ACTION}", ACCELS)

          open_menu_action.signal_connect('activate') { btn.activate }
        end
      end

      def button
        @button ||= Gtk::MenuButton.new.tap do |btn|
          btn.icon_name = 'open-menu-symbolic'
          btn.tooltip_text = 'Main Menu'
          btn.menu_model = menu
        end
      end

      def menu
        @menu ||= Gio::Menu.new.tap do |m|
          ITEMS.each { |label, action| m.append(label, action) }
        end
      end

      def open_menu_action = @open_menu_action ||= Gio::SimpleAction.new(ACTION, nil)
    end
  end
end
