require 'sinatra/base'
require 'reddcoin'
require 'mongoid'

class Mylo < Sinatra::Base

  configure do
    enable :sessions

    set :session_secret, 'MyloApp'

    Mongoid.load!('mongoid.yml')
  end

  helpers do
    def logged_in?
      !!session['access_token']
    end
  end

  get '/' do
    if logged_in?
      redirect '/home'
    end

    erb :index
  end

  run! if app_file == $0
end
