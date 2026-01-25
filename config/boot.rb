ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "logger" # Explicitly require logger to fix ActiveSupport compatibility
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
