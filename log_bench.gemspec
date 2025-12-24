# frozen_string_literal: true

require_relative "lib/log_bench/version"

Gem::Specification.new do |spec|
  spec.name = "log_bench"
  spec.version = LogBench::VERSION
  spec.authors = ["Benjamín Silva"]

  spec.summary = "A terminal-based Rails log viewer with real-time monitoring and filtering capabilities"
  spec.description = "LogBench is a well-structured Ruby gem for parsing and analyzing Rails log files. Supports both Lograge and SemanticLogger formats. Features include real-time log monitoring, interactive TUI with filtering and sorting, domain objects for clean code organization, and support for SQL query analysis."
  spec.homepage = "https://github.com/silva96/log_bench"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.post_install_message = <<~MESSAGE

    🎉 LogBench installed successfully!

    Next steps:
    1. Configure Rails (see README.md for setup instructions)
    2. Restart your Rails server
    3. Make some requests to generate logs
    4. View logs: log_bench log/development.log

    For help: log_bench --help
    Documentation: https://github.com/silva96/log_bench

  MESSAGE

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/silva96/log_bench"
  spec.metadata["changelog_uri"] = "https://github.com/silva96/log_bench/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/silva96/log_bench/issues"
  spec.metadata["documentation_uri"] = "https://github.com/silva96/log_bench/blob/main/README.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "zeitwerk", "~> 2.7"
  spec.add_dependency "curses", "~> 1.5"
  spec.add_dependency "lograge", "~> 0.14"
  spec.add_dependency "net-http", "~> 0.6"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.3"
  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "standard", "~> 1.5"
end
