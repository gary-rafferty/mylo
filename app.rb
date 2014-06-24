require 'sinatra/base'
require 'reddcoin'
require 'recurrence'

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
    erb :home
  end

  get '/recipients' do
    @user = current_user
    @recipients = @user.recipients

    erb :recipients
  end

  get '/recipients/new' do
    @user = current_user

    erb :new_recipients
  end

  post '/recipients/create' do
    user = current_user

    name = params[:name]
    address = params[:address]

    user.recipients.create(name: name, address: address)
  
    redirect '/recipients' 
  end

  get '/subscriptions' do
    @user = current_user
    @subscriptions = @user.subscriptions.reverse

    erb :subscriptions
  end

  get '/subscriptions/new' do
    @user = current_user
    @recipients = @user.recipients

    erb :new_subscriptions
  end

  post '/subscriptions/daily/create' do
    user = current_user

    amount = params[:dailyamount]
    recipient = params[:recipient]
    description = params[:description]
    interval = 'daily'

    recurrence = Recurrence.daily.to_yaml

    subscription = user.subscriptions.build(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    if subscription.save
      redirect '/subscriptions'
    else
      p subscription.errors.inspect
    end
  end
  
  post '/subscriptions/weekly/create' do
    user = current_user

    amount = params[:weeklyamount]
    recipient = params[:recipient]
    day = params[:day]
    description = params[:description]
    interval = 'weekly'
    
    recurrence = Recurrence.weekly(on: day.to_sym).to_yaml

    user.subscriptions.create(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    redirect '/subscriptions'
  end
  
  post '/subscriptions/monthly/create' do
    user = current_user

    amount = params[:monthlyamount]
    recipient = params[:recipient]
    day = params[:day].to_i
    description = params[:description]
    interval = 'monthly'    
    
    recurrence = Recurrence.monthly(on: day).to_yaml

    user.subscriptions.create(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    redirect '/subscriptions'
  end
  
  post '/subscriptions/yearly/create' do
    user = current_user

    amount = params[:yearlyamount]
    recipient = params[:recipient]
    month = params[:month]
    day = params[:day].to_i
    description = params[:description]
    interval = 'yearly'    

    recurrence = Recurrence.yearly(on: [month.to_sym, day]).to_yaml

    user.subscriptions.create(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    redirect '/subscriptions'
  end
  
  get '/transactions' do
    erb :transactions
  end

  get '/schedules' do
    erb :schedules
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
