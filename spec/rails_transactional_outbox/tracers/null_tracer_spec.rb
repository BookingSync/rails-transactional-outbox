# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::Tracers::NullTracer do
  describe ".trace" do
    subject(:trace) { described_class.trace(event_name) }

    let(:event_name) { "event_name" }

    it { is_expected_block.not_to raise_error }
  end
end
