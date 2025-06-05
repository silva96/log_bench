module LogBench
  module App
    class Filter
      def initialize
        self.text = ""
        self.mode = false
      end

      def enter_mode
        self.mode = true
      end

      def exit_mode
        self.mode = false
      end

      def active?
        mode
      end

      def present?
        !text.empty?
      end

      def add_character(char)
        self.text += char
      end

      def remove_character
        self.text = text[0...-1] if text.length > 0
      end

      def clear
        self.text = ""
      end

      def clear_and_exit
        clear
        exit_mode
      end

      def matches?(content)
        return true if text.empty?
        content.to_s.downcase.include?(text.downcase)
      end

      def display_text
        text
      end

      def cursor_display
        active? ? "#{text}█" : text
      end

      private

      attr_accessor :text, :mode
    end
  end
end
