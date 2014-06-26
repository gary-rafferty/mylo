class ScheduledPaymentWorker
  include Sidekiq::Worker

  sidekiq_options :retry => false

  def perform(user_id, recipient_id, amount)
    user = User.where(id: user_id).first
    recipient = Recipient.where(id: recipient_id).first

    begin
      txid = user.send_payment(recipient, amount)

      activity = user.activity.build(
        type: 'scheduled-payment',
        description: 'Made a scheduled payment for '+amount+' to '+recipient.name,
        path: '/transactions/'+txid
      )
      
      if activity.save
      else
        p activity.errors.inspect
      end
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
