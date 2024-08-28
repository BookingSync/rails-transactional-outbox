# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::LatencyTracker, :freeze_time do
  describe "#calculate" do
    subject(:calculate) { described_class.new.calculate }

    before do
      OutboxEntry.delete_all
      RailsTransactionalOutbox.configure do |config|
        config.outbox_model = OutboxEntry
      end
    end

    context "when records exists for the given interval" do
      let!(:entry_1) do
        OutboxEntry.create!(created_at: 2.seconds.ago, processed_at: 1.second.ago, context: "", causality_key: "",
          event_name: "")
      end
      let!(:entry_2) do
        OutboxEntry.create!(created_at: 5.seconds.ago, processed_at: 2.seconds.ago, context: "", causality_key: "",
          event_name: "")
      end
      let!(:entry_3) do
        OutboxEntry.create!(created_at: 120.seconds.ago, processed_at: 61.seconds.ago, context: "", causality_key: "",
          event_name: "")
      end
      let!(:entry_4) do
        OutboxEntry.create!(created_at: 121.seconds.ago, processed_at: nil, context: "", causality_key: "", event_name: "")
      end
      let!(:entry_5) do
        OutboxEntry.create!(created_at: 2.seconds.ago, processed_at: nil, context: "", causality_key: "", event_name: "")
      end

      it "calculates min, max and avg latencies and highest_since_creation_date for the default 1 minute interval" do
        expect(calculate.minimum).to eq 1
        expect(calculate.average).to eq 2
        expect(calculate.maximum).to eq 3
        expect(calculate.highest_since_creation_date).to eq 121
      end
    end

    context "when records do not exist for the given interval" do
      let!(:entry_1) do
        OutboxEntry.create!(created_at: 120.seconds.ago, processed_at: 61.seconds.ago, context: "", causality_key: "",
          event_name: "")
      end

      it "calculates min, max and avg latencies and highest_since_creation_date for the default 1 minute interval" do
        expect(calculate.minimum).to eq 0
        expect(calculate.average).to eq 0
        expect(calculate.maximum).to eq 0
        expect(calculate.highest_since_creation_date).to eq 0
      end
    end
  end
end
