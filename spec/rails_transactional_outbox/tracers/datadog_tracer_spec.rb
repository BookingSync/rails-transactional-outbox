# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::Tracers::DatadogTracer do
  describe "#trace" do
    subject(:trace) { tracer.trace(event_name) { sentinel.call } }

    let(:tracer) { described_class.new }
    let(:event_name) { "event_name" }
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
    let(:message) { double }
    let(:dd_tracer) do
      if Datadog.respond_to?(:tracer)
        Datadog.tracer
      else
        Datadog::Tracing
      end
    end

    before do
      allow(dd_tracer).to receive(:trace).and_call_original
    end

    it "uses Datadog tracer" do
      trace

      expect(dd_tracer).to have_received(:trace).with(event_name,
        hash_including(service: "rails_transactional_outbox_worker", type: "worker", on_error: anything))
    end

    it "yields" do
      expect do
        trace
      end.to change { sentinel.called? }.from(false).to(true)
    end
  end
end
