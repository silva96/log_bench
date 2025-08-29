# frozen_string_literal: true

module LogBench
  module App
    class Clipboard
      def self.copy(text)
        new.copy(text)
      end

      def copy(text)
        # Try different clipboard commands based on the platform
        if system("which pbcopy > /dev/null 2>&1")
          # macOS
          IO.popen("pbcopy", "w") { |io| io.write(text) }
        elsif system("which xclip > /dev/null 2>&1")
          # Linux with xclip
          IO.popen("xclip -selection clipboard", "w") { |io| io.write(text) }
        elsif system("which xsel > /dev/null 2>&1")
          # Linux with xsel
          IO.popen("xsel --clipboard --input", "w") { |io| io.write(text) }
        else
          # Fallback: write to a temporary file
          temp_file = "/tmp/logbench_copy.txt"
          File.write(temp_file, text)
        end
      rescue
        # Silently fail - we don't want to crash the TUI
      end
    end
  end
end
