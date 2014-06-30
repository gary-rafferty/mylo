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

class EmailWorker
  include Sidekiq::Worker

  def perform(user_id, type)
    user = User.where(id: user_id).first
    
    case type
    when 'welcome'
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'Welcome to MYLO',
        body: erb(:welcome_email, layout: false)
      )
    when 'no-redd'
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'Funds too low to fulfil subscriptions',
        body: erb(:no_redd_email, layout: false)
      )
    when 'failed-payment'
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'There was a problem making a payment',
        body: erb(:failed_payment, layout: false)
      )
    end
  end
end
