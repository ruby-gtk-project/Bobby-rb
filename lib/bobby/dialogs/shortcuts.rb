# frozen_string_literal: true

require 'adwaita'

module Bobby
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's src/gtk/dialogs/shortcuts.rs: a General section of
  # five items and a Tables section of one. Upstream also carries a commented
  # out "Jump To Row" item against a shortcut it has not built yet, which is
  # left out here rather than listed as something the app cannot do.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      'General' => [
        ['Open File', '<Primary>o'],
        ['Open Menu', 'F10'],
        ['Reload Window', '<Primary>r'],
        ['Close Window', '<Primary>w'],
        ['Quit', '<Primary>q'],
      ],
      'Tables'  => [
        ['Copy Row', '<Primary>c'],
      ],
    }.freeze

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = title
          items.each { |label, accelerator| section.add(item(label, accelerator)) }
        end
      end

    # Positional, not keyword, arguments — passing them as keywords fails even
    # though the error a no-argument new raises advertises them by name.
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
