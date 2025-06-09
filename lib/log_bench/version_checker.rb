# frozen_string_literal: true

require "net/http"
require "json"
require "fileutils"

module LogBench
  class VersionChecker
    # Cache file location
    CACHE_DIR = File.expand_path("~/.cache/log_bench")
    CACHE_FILE = File.join(CACHE_DIR, "version_check.json")

    # Cache duration (24 hours)
    CACHE_DURATION = 24 * 60 * 60

    # RubyGems API endpoint
    RUBYGEMS_API_URL = "https://rubygems.org/api/v1/gems/log_bench.json"

    # Timeout for HTTP requests
    REQUEST_TIMEOUT = 5

    def self.check_for_update
      new.check_for_update
    end

    def check_for_update
      return nil unless should_check?

      latest_version = fetch_latest_version
      return nil unless latest_version

      update_cache(latest_version)

      if newer_version_available?(latest_version)
        latest_version
      end
    rescue
      # Silently fail - don't interrupt the user experience
      nil
    end

    private

    def should_check?
      return true unless File.exist?(CACHE_FILE)

      cache_data = read_cache
      return true unless cache_data

      # Check if cache is expired
      Time.now - Time.parse(cache_data["checked_at"]) > CACHE_DURATION
    rescue
      true
    end

    def fetch_latest_version
      uri = URI(RUBYGEMS_API_URL)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: REQUEST_TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        return nil unless response.code == "200"

        data = JSON.parse(response.body)
        data["version"]
      end
    rescue
      nil
    end

    def read_cache
      return nil unless File.exist?(CACHE_FILE)

      JSON.parse(File.read(CACHE_FILE))
    rescue
      nil
    end

    def update_cache(latest_version)
      FileUtils.mkdir_p(CACHE_DIR)

      cache_data = {
        "latest_version" => latest_version,
        "checked_at" => Time.now.iso8601
      }

      File.write(CACHE_FILE, JSON.pretty_generate(cache_data))
    rescue
      # Ignore cache write errors
      nil
    end

    def newer_version_available?(latest_version)
      Gem::Version.new(latest_version) > Gem::Version.new(LogBench::VERSION)
    rescue
      false
    end
  end
end
