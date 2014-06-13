require 'sinatra/base'
require 'reddcoin'
require 'mongoid'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: Integer
  field :email, type: String
  field :token, type: String

  index({user_id: 1}, {unique: true, name: 'user_id_index'})
end

class Mylo < Sinatra::Base

  configure do
    enable :sessions

    set :session_secret, 'MyloApp'

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

    user = User.find_or_initialize_by(user_id: user_id).tap do |u|
      u.token = token
      u.email = email
    end

    if user.save!
      session['user_id'] = user.user_id
      200
    else
      500
    end
  end

  get '/sessions/destroy' do
    session.clear
    redirect '/'
  end

  run! if app_file == $0
end
