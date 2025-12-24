# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "log_bench"
require_relative "support/fixtures"

require "minitest/autorun"

module Rails
  def self.env
    @env ||= ActiveSupport::StringInquirer.new("test")
  end

  def self.application
    @application ||= Struct.new(:class) do
      def initialize
        super(Struct.new(:module_parent_name).new("TestApp"))
      end
    end.new
  end
end

# Helper method for tests to get a fresh State instance
def test_state
  state = LogBench::App::State.instance
  state.reset!
  state
end
