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
body = <<eos
Hi there,

Thanks for signing up for MYLO.
There are some things that we need to get off our chest; so here goes.

* MYLO is currently in alpha stages, and should be considered experimental.
* It was built for the ReddAPI app contest (voting for MYLO will make you awesome (if you're already awesome, then it'll make you even more awesome)).
* There is a charge of 1% on all successful transactions. This will likely change.
* It hasn't got a lot of horsepower and might be slow, but if there's enough interest, then I'll pay for some more resources. 

We are working really hard to make it real-world ready.
We will keep you updated as we progress,

Thanks again, 
eos
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'Welcome to MYLO',
        body: body
      )
    when 'no-redd'
body = <<eos
Hi there,

MYLO was just about to make a payment for you, but then we realised that there wasn't enough RDD.

We know you didn't mean this, and obviously we forgive you, but just to be safe, go and top up your MYLO account.

Thanks,
eos
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'Funds too low to fulfil subscriptions',
        body: body
      )
    when 'failed-payment'
body = <<eos
Hi there,

MYLO tried to make a payment for you, but something went wrong.

Don't worry, we're not hurt. Our support team have been notified, and they'll take a look.

We will be in touch,
eos
      Pony.mail(
        from: 'hello@myloapp.herokuapp.com',
        to: user.email,
        subject: 'There was a problem making a payment',
        body: body 
      )
    end
  end
end
