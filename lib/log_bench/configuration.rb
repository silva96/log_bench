# frozen_string_literal: true

module LogBench
  class Configuration
    attr_accessor :show_init_message, :enabled, :base_controller_classes, :configure_lograge_automatically

    def initialize
      @show_init_message = :full
      @enabled = Rails.env.development?
      @base_controller_classes = %w[ApplicationController ActionController::Base]
      @configure_lograge_automatically = true  # Configure lograge by default
    end
  end
end
