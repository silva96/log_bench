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

            # Parse the text to extract segments with their colors
            segments = parse_ansi_segments(text)

            current_chunk = ""
            current_chunk_length = 0
            active_color_state = ""

            segments.each do |segment|
              if segment[:type] == :ansi
                # Track color state
                active_color_state = if segment[:text] == "\e[0m"
                  ""
                else
                  segment[:text]
                end
                current_chunk += segment[:text]
              else
                # Text segment - check if it fits
                text_content = segment[:text]

                while text_content.length > 0
                  remaining_space = max_width - current_chunk_length

                  if text_content.length <= remaining_space
                    # Entire text fits in current chunk
                    current_chunk += text_content
                    current_chunk_length += text_content.length
                    break
                  else
                    # Need to split the text
                    if remaining_space > 0
                      # Take what fits in current chunk
                      chunk_part = text_content[0...remaining_space]
                      current_chunk += chunk_part
                      text_content = text_content[remaining_space..]
                    end

                    # Finish current chunk
                    chunks << current_chunk

                    # Start new chunk with color state
                    current_chunk = active_color_state
                    current_chunk_length = 0
                  end
                end
              end
            end

            # Add final chunk if it has content
            if current_chunk.length > 0
              chunks << current_chunk
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

        def parse_ansi_segments(text)
          segments = []
          remaining = text

          while remaining.length > 0
            # Look for next ANSI sequence
            ansi_match = remaining.match(/^(\e\[[0-9;]*m)/)

            if ansi_match
              # Found ANSI sequence at start
              segments << {type: :ansi, text: ansi_match[1]}
              remaining = remaining[ansi_match[1].length..]
            else
              # Look for ANSI sequence anywhere in remaining text
              next_ansi = remaining.match(/(\e\[[0-9;]*m)/)

              if next_ansi
                # Text before ANSI sequence
                text_before = remaining[0...next_ansi.begin(1)]
                if text_before.length > 0
                  segments << {type: :text, text: text_before}
                end
                remaining = remaining[next_ansi.begin(1)..]
              else
                # No more ANSI sequences, rest is text
                segments << {type: :text, text: remaining}
                break
              end
            end
          end

          segments
        end

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
