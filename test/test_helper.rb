# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "log_bench"
require_relative "support/fixtures"

require "minitest/autorun"

# Helper method for tests to get a fresh State instance
def test_state
  state = LogBench::App::State.instance
  state.reset!
  state
end
