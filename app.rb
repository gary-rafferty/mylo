require 'sinatra/base'
require 'reddcoin'

require_relative 'models'

class Mylo < Sinatra::Base

  configure do
    enable :sessions

    set :session_secret, 'MyloApp'

    Dotenv.load
    Mongoid.load!('mongoid.yml')
  end

  helpers do
    def logged_in?
      !!session['user_id']
    end

    def current_user
      User.where(user_id: session[:user_id]).first
    end
  end

  get '/' do
    if logged_in?
      redirect '/home'
    end

    erb :index
  end

  get '/home' do
    'home'
  end

  post '/sessions/new' do
    user_id = params[:user_id]
    token = params[:token]
    email = params[:email]

    if user = User.find_by(user_id: user_id)
      user.update_attribute(:token, token)
      session['user_id'] = user.user_id
      200
    else
      begin
        user = User.new(
          user_id: user_id,
          token: token,
          email: email,
          address: ReddcoinAddress.generate(email)
        )

        if user.save!
          session['user_id'] = user.user_id
          200
        else
          500
        end
      rescue
        500
      end
    end
  end

  get '/sessions/destroy' do
    session.clear
    redirect '/'
  end

  run! if app_file == $0
end
