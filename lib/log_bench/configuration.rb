# frozen_string_literal: true

module LogBench
  class Configuration
    attr_accessor :show_init_message, :enable

    def initialize
      @show_init_message = :full
      @enable = true
    end
  end
end
