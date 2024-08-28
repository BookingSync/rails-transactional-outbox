# frozen_string_literal: true

class RailsTransactionalOutbox
  class DatadogLatencyReporterJob
    include Sidekiq::Worker

    sidekiq_options queue: RailsTransactionalOutbox::Configuration.high_priority_sidekiq_queue

    def perform
      RailsTransactionalOutbox::DatadogLatencyReporter.new.report
    end
  end
end
