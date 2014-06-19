require 'mongoid'
require 'dotenv'

class APIError < Exception; ;end

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: Integer
  field :email, type: String
  field :token, type: String

  index({user_id: 1}, {unique: true, name: 'user_id_index'})
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


