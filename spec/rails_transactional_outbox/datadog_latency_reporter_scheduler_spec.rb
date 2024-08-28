# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::DatadogLatencyReporterScheduler do
  describe "#add_to_schedule" do
    subject(:add_to_schedule) { described_class.new.add_to_schedule }

    let(:redis_url) { ENV.fetch("REDIS_URL") }
    let(:redis_namespace) { described_class.to_s }

    before do
      Sidekiq.configure_client do |config|
        config.redis = { url: redis_url, namespace: redis_namespace }
      end
      Sidekiq.redis do |sidekiq_connection|
        sidekiq_connection.redis.flushdb
        sidekiq_connection.keys("cron_job*").each do |key|
          sidekiq_connection.del(key)
        end
      end
    end

    context "when the job already exists" do
      before do
        add_to_schedule
      end

      it "does not add a new job to the schedule" do
        expect do
          add_to_schedule
        end.not_to change { Sidekiq::Cron::Job.count }
      end
    end

    context "when the job does not exist" do
      let(:created_job) do
        Sidekiq::Cron::Job.find(name: "rails_transactional_outbox_datadog_latency_reporter_job")
      end
      let(:description) do
        "Collect latency metrics from rails-transactional-outbox and send them to Datadog"
      end

      it "adds a new job to the schedule" do
        expect do
          add_to_schedule
        end.to change { Sidekiq::Cron::Job.count }.from(0).to(1)

        expect(created_job.name).to eq "rails_transactional_outbox_datadog_latency_reporter_job"
        expect(created_job.cron).to eq "* * * * *"
        expect(created_job.klass).to eq "RailsTransactionalOutbox::DatadogLatencyReporterJob"
        expect(created_job.queue_name_with_prefix).to eq "rails_transactional_outbox_high_priority"
        expect(created_job.date_as_argument?).to be false
        expect(created_job.description).to eq description
      end
    end
  end
end
