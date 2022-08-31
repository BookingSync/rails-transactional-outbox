# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox do
  describe "version" do
    it "has a version number" do
      expect(RailsTransactionalOutbox::VERSION).not_to be_nil
    end
  end

  describe ".loader" do
    subject(:loader) { described_class.loader }

    it { is_expected.to be_a(Zeitwerk::GemLoader) }
  end

  describe ".configuration/.configure" do
    subject(:configuration) { described_class.configuration }

    let(:logger) { configuration.logger }

    before do
      described_class.configure do |config|
        config.logger = :logger
      end
    end

    it { is_expected.to be_a(RailsTransactionalOutbox::Configuration) }

    it "allows to set the configuration" do
      expect(logger).to eq :logger
    end
  end

  describe ".monitor" do
    subject(:monitor) { described_class.monitor }

    it { is_expected.to be_a(RailsTransactionalOutbox::Monitor) }
  end

  describe ".reset" do
    subject(:reset) { described_class.reset }

    before do
      described_class.configuration
    end

    it "resets the configuration" do
      expect do
        reset
      end.to change { described_class.instance_variable_get(:@configuration) }.to(nil)
    end
  end

  describe ".outbox_worker_health_check" do
    subject(:outbox_worker_health_check) { described_class.outbox_worker_health_check }

    it { is_expected.to be_a(RailsTransactionalOutbox::HealthCheck) }
  end

  describe ".enable_outbox_worker_healthcheck" do
    subject(:enable_outbox_worker_healthcheck) { described_class.enable_outbox_worker_healthcheck }

    before do
      allow(described_class.monitor).to receive(:subscribe).and_call_original
    end

    it "subscribes to outbox worker events" do
      enable_outbox_worker_healthcheck

      expect(described_class.monitor).to have_received(:subscribe).with("rails_transactional_outbox.started")
      expect(described_class.monitor).to have_received(:subscribe).with("rails_transactional_outbox.stopped")
      expect(described_class.monitor).to have_received(:subscribe).with("rails_transactional_outbox.heartbeat")
    end
  end
end
