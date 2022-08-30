# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::Monitor do
  describe "subscribe/publish" do
    let(:monitor) { described_class.new }
    let(:sentinel) do
      Class.new do
        def call
          @called = true
        end

        def called?
          @called == true
        end
      end.new
    end

    context "when the event exists" do
      subject(:publish) { monitor.publish("rails_transactional_outbox.started") }

      before do
        monitor.subscribe("rails_transactional_outbox.started") do |_event|
          sentinel.call
        end
      end

      it "allows the event to be subscribed to" do
        expect do
          publish
        end.to change { sentinel.called? }.from(false).to(true)
      end
    end

    context "when the event does not exist" do
      subject(:subscribe) { monitor.subscribe(event_name) }

      let(:event_name) { "rails_transactional_outbox.event_with_typo" }

      it { is_expected_block.to raise_error(%r{unknown event: rails_transactional_outbox.event_with_typo}) }
    end
  end

  describe "#events" do
    subject(:events) { monitor.events }

    let(:monitor) { described_class.new }
    let(:available_events) do
      %w[
        rails_transactional_outbox.started
        rails_transactional_outbox.stopped
        rails_transactional_outbox.shutting_down
        rails_transactional_outbox.record_processing_failed
        rails_transactional_outbox.record_processed
        rails_transactional_outbox.error
        rails_transactional_outbox.heartbeat
      ]
    end

    it { is_expected.to eq available_events }
  end
end
