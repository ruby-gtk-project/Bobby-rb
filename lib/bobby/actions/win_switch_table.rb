# frozen_string_literal: true

#   Bobby, browse SQLite files
#   Copyright (C) 2025  Hylke Bons (hello@planetpeanut.studio)
#   Copyright (C) 2026  ruby-gtk-project, for the Ruby port
#
#   This program is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License v3 or any later version.

require 'gtk4'

module Bobby
  module Actions
    # win.table is which table the window is showing.
    #
    # Ported from upstream's src/gtk/actions/win_switch_table.rs. A stateful
    # action whose state is the table's index as a string, which is what lets
    # the switcher menu tick the open table; the items in that menu all target
    # win.table::<index>.
    #
    # Upstream takes the layout box, the table list and the switcher as
    # arguments and reaches into them from the handler, calling the shape ugly
    # in a comment beside it; here the window owns all three and does the
    # swap, so the action only has to say which index was asked for.
    class WinSwitchTable
      NAME = 'table'

      def initialize(window) = @window = window

      attr_reader :window

      def build
        action.tap do |a|
          a.signal_connect('change-state') { |_, value| change_state(value) }
        end
      end

      def action
        @action ||= Gio::SimpleAction.new(
          NAME,
          GLib::VariantType.new('s'),
          GLib::Variant.new(window.table_index.to_s),
        )
      end

      private

        # The state is set first, so the menu's tick follows even when the
        # table itself cannot be shown.
        def change_state(value)
          value.to_s.then do |state|
            action.set_state(GLib::Variant.new(state))
            Integer(state, exception: false).then do |index|
              unless index.nil?
                window.switch_table(index)
              end
            end
          end
        end
    end
  end
end
