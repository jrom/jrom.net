# Use locked gems if present.
begin
  require File.expand_path('.bundle/environment', __FILE__)

rescue LoadError
  # Otherwise, use RubyGems.
  require 'rubygems'

  # And set up the gems listed in the Gemfile.
  if File.exist?(File.expand_path('Gemfile', __FILE__))
    require 'bundler'
    Bundler.setup
  end
end

Bundler.require(:default, ENV['RACK_ENV']) if defined?(Bundler)

require 'app'

log = File.new("log/#{Sinatra::Application.environment}.log", "a+")
STDOUT.reopen(log)
STDERR.reopen(log)

run Jrom::Application
