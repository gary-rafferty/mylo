require 'mongoid'
require 'dotenv'

class APIError < Exception; ;end

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: Integer
  field :email, type: String
  field :token, type: String
  field :address, type: String

  has_many :recipients, order: :created_at.desc
  has_many :subscriptions, order: :created_at.desc
  has_many :activities, order: :created_at.desc

  index({user_id: 1}, {unique: true, name: 'user_id_index'})

  def current_balance
    client = Reddcoin::Client.new(get: ENV['GET_KEY'], post: ENV['POST_KEY'])
    balance = client.get_user_balance_detail(email)

    balance
  end

  def send_payment(recipient, amount)
    client = Reddcoin::Client.new(get: ENV['GET_KEY'], post: ENV['POST_KEY'])

    if response = client.send_to_address(email, recipient.address, amount)
      if response.is_a? Hash and response.has_key? 'ErrorMessage'
        raise APIError.new('Error creating payment of '+amount.to_s+' to '+recipient.id.to_s+' for '+id.to_s)
      else
        response
      end
    else
      raise APIError.new('Error creating payment of '+amount.to_s+' to '+recipient.id.to_s+' for '+id.to_s)
    end
  end

  def handle_subscriptions
    subscriptions.each do |s|
      if s.due_today?
        s.fulfil
      end
    end
  end
end

class Recipient
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :address, type: String

  belongs_to :user

  has_many :subscriptions
end

class Subscription
  include Mongoid::Document
  include Mongoid::Timestamps

  field :amount, type: Integer
  field :description, type: String
  field :recurrence, type: String
  field :interval, type: String

  validates_inclusion_of :interval, in: ['daily', 'weekly', 'monthly', 'yearly']
  
  belongs_to :recipient
  belongs_to :user

  def next_recurrence
    YAML.load(recurrence).next
  end

  def due_today?
    YAML.load(recurrence).include? Date.today
  end

  def fulfil
    begin
      txid = user.send_payment(recipient, amount)
      
      advance_recurrence!

      user.activities.create(
        type: 'fulfil-subscription',
        description: 'Fulfilled a subscription payment for '+amount.to_s+' to '+recipient.name,
        path: '/transactions/'+txid
      )
    rescue Exception => e
      Rollbar.report_exception(e)
    end
  end

  private

  def advance_recurrence!
    recurrence_obj = YAML.load(recurrence)
    recurrence_obj.next!

    advanced_recurrence = recurrence_obj.to_yaml

    self.update_attributes(recurrence: advanced_recurrence)
  end
end

class Activity
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :description, type: String
  field :path, type: String

  belongs_to :user

  scope :transactions, where(:type.in => ['scheduled-payment','fulfil-subscription'])
end

class ReddcoinAddress
  class << self
    def generate username
      client = Reddcoin::Client.new(get: ENV['GET_KEY'], post: ENV['POST_KEY'])
      if response = client.create_new_user(username)
        response['DepositAddress']
      else
        raise APIError.new 'Error creating the new address'
      end
    end
  end
end
