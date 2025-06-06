# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class Ansi
        include Curses

        def initialize(screen)
          self.screen = screen
        end

        def has_ansi_codes?(text)
          text.match?(/\e\[[0-9;]*m/)
        end

        def parse_and_render(text, win)
          parts = text.split(/(\e\[[0-9;]*m)/)
          current_color = nil

          parts.each do |part|
            if part =~ /\e\[([0-9;]*)m/
              # ANSI escape code
              codes = $1.split(";").map(&:to_i)
              current_color = ansi_to_curses_color(codes)
            elsif current_color && !part.empty?
              # Text content
              win.attron(current_color) { win.addstr(part) }
            elsif !part.empty?
              win.addstr(part)
            end
          end
        end

        def wrap_ansi_text(text, max_width)
          clean_text = text.gsub(/\e\[[0-9;]*m/, "")

          if clean_text.length <= max_width
            [text]
          else
            chunks = []
            remaining = text
            active_colors = []

            # Extract initial color state
            text.scan(/\e\[[0-9;]*m/) do |ansi_code|
              if /\e\[0m/.match?(ansi_code)
                active_colors.clear
              else
                active_colors << ansi_code
              end
            end

            while remaining.length > 0
              clean_remaining = remaining.gsub(/\e\[[0-9;]*m/, "")

              if clean_remaining.length <= max_width
                # Last chunk
                chunks << if active_colors.any? && !remaining.start_with?(*active_colors)
                  active_colors.join("") + remaining
                else
                  remaining
                end
                break
              else
                # Find break point and preserve color state
                break_point = max_width
                original_pos = 0
                clean_pos = 0
                chunk_colors = active_colors.dup

                remaining.each_char.with_index do |char, idx|
                  if /^\e\[[0-9;]*m/.match?(remaining[idx..])
                    # Found ANSI sequence
                    ansi_match = remaining[idx..].match(/^(\e\[[0-9;]*m)/)
                    ansi_code = ansi_match[1]

                    if /\e\[0m/.match?(ansi_code)
                      chunk_colors.clear
                      active_colors.clear
                    else
                      chunk_colors << ansi_code unless chunk_colors.include?(ansi_code)
                      active_colors << ansi_code unless active_colors.include?(ansi_code)
                    end

                    original_pos += ansi_code.length
                    idx + ansi_code.length - 1
                  else
                    clean_pos += 1
                    original_pos += 1

                    if clean_pos >= break_point
                      break
                    end
                  end
                end

                chunk_text = remaining[0...original_pos]
                chunks << if active_colors.any? && !chunk_text.start_with?(*active_colors)
                  active_colors.join("") + chunk_text
                else
                  chunk_text
                end

                remaining = remaining[original_pos..]
              end
            end

            chunks
          end
        end

        def wrap_plain_text(text, max_width)
          # Simple text wrapping for plain text
          if text.length <= max_width
            [text]
          else
            chunks = []
            remaining = text

            while remaining.length > 0
              if remaining.length <= max_width
                chunks << remaining
                break
              else
                # Find a good break point (try to break on spaces)
                break_point = max_width
                if remaining[0...max_width].include?(" ")
                  # Find the last space within the limit
                  break_point = remaining[0...max_width].rindex(" ") || max_width
                end

                chunks << remaining[0...break_point]
                remaining = remaining[break_point..].lstrip
              end
            end

            chunks
          end
        end

        private

        attr_accessor :screen

        def ansi_to_curses_color(codes)
          # Convert ANSI color codes to curses color pairs
          return nil if codes.empty? || codes == [0]

          # Handle common ANSI codes
          codes.each do |code|
            case code
            when 1 then return color_pair(7) | A_BOLD  # Bold/bright
            when 30 then return color_pair(8) # Black
            when 31 then return color_pair(6) # Red
            when 32 then return color_pair(3) # Green
            when 33 then return color_pair(4) # Yellow
            when 34 then return color_pair(5) # Blue
            when 35 then return color_pair(9) # Magenta
            when 36 then return color_pair(1) # Cyan
            when 37 then return nil           # White (default)
            end
          end

          nil
        end

        def color_pair(n)
          screen.color_pair(n)
        end
      end
    end
  end
end
