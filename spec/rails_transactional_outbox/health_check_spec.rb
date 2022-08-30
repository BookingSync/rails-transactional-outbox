# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::HealthCheck do
  let(:redis_client) { Redis.new(url: ENV.fetch("REDIS_URL", nil)) }
  let(:key) { "__rails_transactional__outbox_worker__running__hostname" }

  before do
    redis_client.del(key)
  end

  around do |example|
    original_hostname = ENV.fetch("HOSTNAME", nil)
    ENV["HOSTNAME"] = "hostname"

    example.run

    ENV["HOSTNAME"] = original_hostname
  end

  describe ".check" do
    subject(:check) { health_check.check }

    let(:health_check) { described_class }

    context "when expected value was not set yet in Redis" do
      let(:expected_result) do
        "[Rails Transactional Outbox Worker - expected OK under #{key}, found: ] "
      end

      it { is_expected.to eq expected_result }
    end

    context "when expected value was set in Redis but it's an incorrect one" do
      let(:value) { "other" }
      let(:expected_result) do
        "[Rails Transactional Outbox Worker - expected OK under #{key}, found: #{value}] "
      end

      before do
        redis_client.set(key, value)
      end

      it { is_expected.to eq expected_result }
    end

    context "when expected value was set in Redis and it's a correct one" do
      let(:health_check) { described_class }

      before do
        health_check.new.register_heartbeat
      end

      after do
        health_check.new.worker_stopped
      end

      it { is_expected.to eq "" }
    end
  end

  describe "#register_heartbeat" do
    subject(:register_heartbeat) { health_check.register_heartbeat }

    let(:health_check) { described_class.new }

    before do
      allow(Redis).to receive(:new).and_return(redis_client)
      allow(redis_client).to receive(:set).and_call_original
    end

    it "sets OK value under special key in Redis" do
      expect do
        register_heartbeat
      end.to change { redis_client.get(key) }.from(nil).to("OK")
    end

    it "sets expiry time for the key" do
      register_heartbeat

      expect(redis_client).to have_received(:set).with(key, anything, ex: 120)
    end
  end

  describe "#worker_stopped" do
    subject(:worker_stopped) { health_check.worker_stopped }

    let(:health_check) { described_class.new }

    before do
      health_check.register_heartbeat
    end

    it "sets nil under special key in Redis" do
      expect do
        worker_stopped
      end.to change { redis_client.get(key) }.from("OK").to(nil)
    end
  end
end
