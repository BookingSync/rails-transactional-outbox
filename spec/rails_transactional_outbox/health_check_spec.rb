# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::HealthCheck do
  let(:healthcheck_storage) do
    FileBasedHealthcheck.new(directory: directory, filename: key, time_threshold: 120)
  end
  let(:directory) { "/tmp" }
  let(:key) { "__rails_transactional__outbox_worker__running__hostname" }

  around do |example|
    original_hostname = ENV.fetch("HOSTNAME", nil)
    ENV["HOSTNAME"] = "hostname"

    example.run

    ENV["HOSTNAME"] = original_hostname
  end

  after do
    healthcheck_storage.remove
  end

  describe ".check" do
    subject(:check) { health_check.check }

    let(:health_check) { described_class }

    context "when the heartbeat has not been registered" do
      let(:expected_result) { "[Rails Transactional Outbox Worker healthcheck failed]" }

      it { is_expected.to eq expected_result }
    end

    context "when the heartbeat has been registered" do
      let(:health_check) { described_class }

      before do
        healthcheck_storage.touch
      end

      it { is_expected.to eq "" }
    end
  end

  describe "#register_heartbeat" do
    subject(:register_heartbeat) { health_check.register_heartbeat }

    let(:health_check) { described_class.new }

    it "registers a heartbeat" do
      expect do
        register_heartbeat
      end.to change { healthcheck_storage.running? }.from(false).to(true)
    end
  end

  describe "#worker_stopped" do
    subject(:worker_stopped) { health_check.worker_stopped }

    let(:health_check) { described_class.new }

    before do
      health_check.register_heartbeat
    end

    it "removes the registry for hearbeats" do
      expect do
        worker_stopped
      end.to change { healthcheck_storage.running? }.from(true).to(false)
    end
  end
end
