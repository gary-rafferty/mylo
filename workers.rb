class ScheduledPaymentWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  def perform(user_id, recipient_id, amount)
    user = User.where(id: user_id).first
    recipient = Recipient.where(id: recipient_id).first

    begin
      txid = user.send_payment(recipient, amount)

      user.activities.create(
        type: 'scheduled-payment',
        description: 'Made a scheduled payment of '+amount.to_s+' to '+recipient.name,
        path: '/transactions/'+txid
      )
    rescue
      # handle
    end
  end
end

class SubscriptionWorker
  include Sidekiq::Worker

  def perform
    User.all.each { |u| u.handle_subscriptions }
  end
end
