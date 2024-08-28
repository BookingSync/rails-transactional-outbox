# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::DatadogLatencyReporter, :freeze_time do
  describe "#report" do
    subject(:report) { described_class.new.report }

    let(:datadog_statsd_client) { Datadog::Statsd.new("localhost", 8125, namespace: "gem") }
    let!(:entry_1) do
      OutboxEntry.create!(created_at: 2.seconds.ago, processed_at: 1.second.ago, context: "",
        event_name: "", causality_key: "")
    end
    let!(:entry_2) do
      OutboxEntry.create!(created_at: 5.seconds.ago, processed_at: 2.seconds.ago, context: "",
        event_name: "", causality_key: "")
    end
    let!(:entry_3) do
      OutboxEntry.create!(created_at: 10.seconds.ago, processed_at: nil, context: "",
        event_name: "", causality_key: "")
    end

    before do
      OutboxEntry.where.not(id: [entry_1.id, entry_2.id, entry_3.id]).delete_all
      allow(datadog_statsd_client).to receive(:gauge).and_call_original

      RailsTransactionalOutbox.configure do |conf|
        conf.outbox_model = OutboxEntry
        conf.datadog_statsd_client = datadog_statsd_client
      end
    end

    it "reports latency metrics to datadog" do
      report

      expect(datadog_statsd_client).to have_received(:gauge).with(
        "rails_transactional_outbox.latency.minimum", 1
      )
      expect(datadog_statsd_client).to have_received(:gauge).with(
        "rails_transactional_outbox.latency.maximum", 3
      )
      expect(datadog_statsd_client).to have_received(:gauge).with(
        "rails_transactional_outbox.latency.average", 2
      )
      expect(datadog_statsd_client).to have_received(:gauge).with(
        "rails_transactional_outbox.latency.highest_since_creation_date", 10
      )
    end
  end
end
