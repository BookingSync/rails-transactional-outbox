# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::DatadogLatencyReporterJob, type: :job do
  it { is_expected.to be_processed_in :rails_transactional_outbox_high_priority }

  describe "#perform" do
    subject(:perform) { described_class.new.perform }

    it "calls RailsTransactionalOutbox::DatadogLatencyReporter" do
      expect_any_instance_of(RailsTransactionalOutbox::DatadogLatencyReporter).to receive(:report)

      perform
    end
  end
end
