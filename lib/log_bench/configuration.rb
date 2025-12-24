# frozen_string_literal: true

module LogBench
  class Configuration
    attr_accessor :show_init_message, :enabled, :base_controller_classes, :configure_logger_automatically, :logger_type

    def initialize
      @show_init_message = :full
      @enabled = defined?(Rails) && Rails.env.development?
      @base_controller_classes = %w[ApplicationController ActionController::Base]
      @configure_logger_automatically = true
      @logger_type = :lograge
    end
  end
end
