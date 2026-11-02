# frozen_string_literal: true

require 'gtk4'

require_relative '../log'
require_relative '../sqlite/affinity'

module Bobby
  module Widgets
    # Item is the pair of cell widgets a ColumnView row is made of.
    #
    # Ported from upstream's src/gtk/widgets/item.rs. A SignalListItemFactory
    # calls `setup` once per recycled row to build the widget, then `bind`
    # every time that widget is reused for a different row, so the two halves
    # are separate: setup hands the list item a Label, bind writes this row's
    # text into one that already exists.
    #
    # Every write re-reads the current value first, as upstream does: a
    # ColumnView recycles cells aggressively, and setting a label's text to
    # what it already holds still queues a resize.
    #
    # The tooltip goes on the label's parent — the cell widget the ListItem
    # wraps the label in — rather than on the label, because a label narrower
    # than its cell would leave the rest of the cell tooltip-less.
    module Item
      MARGIN = 4

      # U+25C7 "White Diamond", the primary-key marker.
      SYMBOL_KEY = '◇'

      class << self
        def write_text(label, text)
          unless label.text == text
            label.text = text
          end
        end

        def write_name(label, name)
          unless label.name == name
            label.name = name
          end
        end

        def write_tooltip(label, text)
          label.parent.then do |parent|
            if !parent.nil? && parent.tooltip_text != text
              parent.tooltip_text = text
            end
          end
        end
      end

      # IndexCell is column 0: the row number, dimmed and monospace so the
      # digits line up, with "n / total" as its tooltip.
      module IndexCell
        class << self
          def setup(list_item)
            list_item.child = label
          end

          def bind(list_item, row_count)
            (list_item.position + 1).then do |row_number|
              Item.write_text(list_item.child, row_number.to_s)
              Item.write_tooltip(list_item.child, "#{row_number} / #{row_count}")
            end
          end

          private

            def label
              Gtk::Label.new.tap do |l|
                l.add_css_class('dimmed')
                l.add_css_class('monospace')
                l.halign = :end
                l.has_tooltip = true
                l.margin_start = MARGIN
                l.margin_end = MARGIN
                l.margin_top = 1
                l.single_line_mode = true
              end
            end
        end
      end

      # ValueCell is every other column: one cell's value, left-aligned, in
      # the "numeric" style so digits are tabular. NULLs and blobs are dimmed
      # because what they show — an em dash, a byte count — is not the value
      # itself.
      #
      # The label carries its column index as its widget name. That is how the
      # context-menu gesture works out which cell was right-clicked: it picks
      # the widget under the pointer and reads the name back off it, because
      # Gtk::ColumnView will not say which cell a click landed in.
      module ValueCell
        class << self
          def setup(list_item, monospace_font)
            list_item.child = label(monospace_font)
          end

          # column_index counts the reserved row-number column, so the cell is
          # one to its left.
          def bind(list_item, column_index, primary_key)
            list_item.item.row.cell(column_index - 1).then do |cell|
              if cell.nil?
                Log.error('Missing column')
              else
                write_cell(
                  list_item.child,
                  cell,
                  column_index,
                  primary_key,
                )
              end
            end
          end

          private

            def write_cell(label, cell, column_index, primary_key)
              Item.write_text(label, cell.to_s)
              Item.write_name(label, column_index.to_s)
              Item.write_tooltip(label, tooltip_for(cell, primary_key))
              write_dimmed(label, cell.dimmed?)
            end

            def label(monospace_font)
              Gtk::Label.new.tap do |l|
                l.add_css_class('numeric')
                l.xalign = 0.0
                l.has_tooltip = true
                l.margin_start = MARGIN
                l.single_line_mode = true
                if monospace_font
                  l.add_css_class('monospace')
                  l.margin_top = 1
                end
              end
            end

            # Upstream prefixes a primary-key cell's tooltip with the diamond
            # and PRIMARY_KEY, so the key column is identifiable without
            # reading the header.
            def tooltip_for(cell, primary_key)
              cell.tooltip.then do |text|
                if primary_key
                  "#{SYMBOL_KEY} PRIMARY_KEY  #{text}"
                else
                  text
                end
              end
            end

            def write_dimmed(label, dimmed)
              if dimmed
                label.add_css_class('dimmed')
              else
                label.remove_css_class('dimmed')
              end
            end
        end
      end
    end
  end
end
