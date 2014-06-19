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

  has_many :payees
  has_many :subscriptions

  index({user_id: 1}, {unique: true, name: 'user_id_index'})
end

class Payee
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

  belongs_to :payee
  belongs_to :user
end

class Payment
  include Mongoid::Document
  include Mongoid::Timestamps

  field :amount, type: Integer
  field :address, type: String
  field :type, type: String

  validates_inclusion_of :type, in: ['Subscription', 'Oneoff']

  belongs_to :user
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


