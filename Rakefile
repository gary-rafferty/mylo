require 'rake/testtask'

desc 'Start the web server (thin)'
task :server do
  sh 'shotgun --server=thin --port=3000 config.ru'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*.rb']
  t.verbose = true
end

desc 'Start the subscription worker'
task :worker do
  require './app'
  
  SubscriptionWorker.perform_async
end
