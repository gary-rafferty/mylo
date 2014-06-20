$:.unshift(File.join(File.dirname(__FILE__), '..'))

require 'sinatra/base'

Sinatra::Base.set :environment, :test

require 'minitest/autorun'
require 'app'
