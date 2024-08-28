# frozen_string_literal: true

class RailsTransactionalOutbox
  class DatadogLatencyReporterScheduler
    JOB_NAME = "rails_transactional_outbox_datadog_latency_reporter_job"
    EVERY_MINUTE_IN_CRON_SYNTAX = "* * * * *"
    JOB_CLASS_NAME = "RailsTransactionalOutbox::DatadogLatencyReporterJob"
    JOB_DESCRIPTION = "Collect latency metrics from rails-transactional-outbox and send them to Datadog"

    private_constant :JOB_NAME, :EVERY_MINUTE_IN_CRON_SYNTAX, :JOB_CLASS_NAME, :JOB_DESCRIPTION

    attr_reader :config
    private :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def add_to_schedule
      find || create
    end

    private

    def find
      Sidekiq::Cron::Job.find(name: JOB_NAME)
    end

    def create
      Sidekiq::Cron::Job.create(create_job_arguments)
    end

    def create_job_arguments
      {
        name: JOB_NAME,
        cron: EVERY_MINUTE_IN_CRON_SYNTAX,
        class: JOB_CLASS_NAME,
        queue: config.high_priority_sidekiq_queue,
        active_job: false,
        description: JOB_DESCRIPTION,
        date_as_argument: false
      }
    end

    def every_minute_to_cron_syntax
      EVERY_MINUTE_IN_CRON_SYNTAX
    end
  end
end
