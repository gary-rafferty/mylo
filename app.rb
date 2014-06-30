require 'sinatra/base'
require 'reddcoin'
require 'recurrence'
require 'sidekiq'
require 'active_support/core_ext'
require 'rollbar'
require 'pony'

require_relative 'models'
require_relative 'workers'

class Mylo < Sinatra::Base

  configure do
    enable :sessions
    set :session_secret, 'MyloApp'

    Dotenv.load
    Mongoid.load!('mongoid.yml')

    Rollbar.configure do |config|
      config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
    end
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
    @user = current_user
    @balances = @user.current_balance.inject({}) do |hash, (k,v)|
      hash.merge(k => v.to_f)
    end

    @activities = @user.activities.limit(5)

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

  get '/recipients/:id' do
    id = params[:id]

    if @recipient = Recipient.where(id: id).first
      erb :recipient
    else
      500
    end
  end

  post '/recipients/create' do
    user = current_user

    name = params[:name]
    address = params[:address]

    recipient = user.recipients.build(name: name, address: address)
  
    if recipient.save
      user.activities.create(
        type: 'add-recipient',
        description: 'Added a new recipient',
        path: '/recipients/'+recipient.id
      )
    
      redirect '/recipients' 
    else
      p recipient.errors.inspect
    end
  end

  get '/subscriptions' do
    @user = current_user
    @subscriptions = @user.subscriptions

    erb :subscriptions
  end

  get '/subscriptions/new' do
    @user = current_user
    @recipients = @user.recipients

    erb :new_subscriptions
  end

  get '/subscriptions/:id' do
    id = params[:id]

    if @subscription = Subscription.where(id: id).first
      erb :subscription
    else
      500
    end
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
      user.activities.create(
        type: 'add-subscription',
        description: 'Added a new subscription',
        path: '/subscriptions/'+subscription.id
      )
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

    subscription = user.subscriptions.build(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    if subscription.save
      user.activities.create(
        type: 'add-subscription',
        description: 'Added a new subscription',
        path: '/subscriptions/'+subscription.id
      )
      redirect '/subscriptions'
    else
      p subscription.errors.inspect
    end
  end
  
  post '/subscriptions/monthly/create' do
    user = current_user

    amount = params[:monthlyamount]
    recipient = params[:recipient]
    day = params[:day].to_i
    description = params[:description]
    interval = 'monthly'    
    
    recurrence = Recurrence.monthly(on: day).to_yaml

    subscription = user.subscriptions.build(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    if subscription.save
      user.activities.create(
        type: 'add-subscription',
        description: 'Added a new subscription',
        path: '/subscriptions/'+subscription.id
      )
      redirect '/subscriptions'
    else
      p subscription.errors.inspect
    end
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

    subscription = user.subscriptions.build(
      amount: amount,
      recipient_id: recipient,
      description: description,
      interval: interval,
      recurrence: recurrence
    )

    if subscription.save
      user.activities.create(
        type: 'add-subscription',
        description: 'Added a new subscription',
        path: '/subscriptions/'+subscription.id
      )
      redirect '/subscriptions'
    else
      p subscription.errors.inspect
    end
  end
  
  get '/transactions' do
    @user = current_user
    @transactions = @user.activities.transactions

    erb :transactions
  end

  get '/schedules' do
    @user = current_user
    @recipients = @user.recipients

    erb :schedules
  end

  post '/schedules/create' do
    user = current_user

    quantity = params[:quantity].to_i
    interval = params[:interval]
    amount   = params[:amount].to_i
    recipient= params[:recipient].to_s

    time = quantity.send(interval.to_sym)
 
    ScheduledPaymentWorker.perform_in(time, user.id.to_s, recipient, amount)

    redirect '/schedules' # should go to a success page
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

        if user.save
          session['user_id'] = user.user_id
          200
        else
          p user.errors.inspect
          500
        end
      rescue Exception => e
        Rollbar.report_exception(e)
        500
      end
    end
  end

  get '/faq' do
    erb :faq
  end

  get '/sessions/destroy' do
    session.clear
    redirect '/'
  end

  run! if app_file == $0
end
