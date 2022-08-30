# frozen_string_literal: true

namespace :rails_transactional_outbox do
  desc "Starts the RailsTransactionalOutbox worker"
  task worker: :environment do
    $stdout.sync = true
    Rails.logger.info("Running rails_transactional_outbox:worker rake task.")
    threads_number = ENV.fetch("RAILS_TRANSACTIONAL_OUTBOX_THREADS_NUMBER", 1).to_i
    RailsTransactionalOutbox.start_worker(threads_number: threads_number)
  end
end
