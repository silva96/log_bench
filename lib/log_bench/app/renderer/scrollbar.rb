# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class Scrollbar
        include Curses

        def initialize(screen)
          self.screen = screen
        end

        def draw(win, height, offset, total)
          return if total <= height

          scrollbar_height = [(height * height / total), 1].max
          scrollbar_pos = offset * height / total

          x = win.maxx - 2  # Position scrollbar closer to the border
          height.times do |i|
            win.setpos(i + 1, x)
            if i >= scrollbar_pos && i < scrollbar_pos + scrollbar_height
              win.attron(color_pair(1)) { win.addstr("█") }  # Solid block for scrollbar thumb
            end
          end
        end

        private

        attr_accessor :screen

        def color_pair(n)
          screen.color_pair(n)
        end
      end
    end
  end
end
