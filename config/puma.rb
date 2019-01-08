workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

if ENV['RAILS_ENV'] == 'development'
  puts "LOGGER: development => worker_timeout 3600"
  worker_timeout 3600
end

on_worker_boot do
  # Ensure we don't keep connections
  if defined?(Sequel)
    ::Sequel::Model.db.disconnect
    ::Sequel::DATABASES.each{|db| db.disconnect }
  end
end

after_worker_boot do
  SequelRails.setup Rails.env if defined?(SequelRails)
end
