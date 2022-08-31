# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::ReliableModel::ReliableCallbacksRegistry do
  describe "#<</#for_event_type" do
    subject(:for_event_type) { registry.for_event_type(event_type) }

    let(:registry) { described_class.new }
    let(:callback) do
      RailsTransactionalOutbox::ReliableModel::ReliableCallback.new(double, on: :create)
    end

    before do
      registry << callback
    end

    context "when there is an callback for a given type" do
      let(:event_type) { :create }

      it { is_expected.to eq([callback]) }
    end

    context "when there are no callbacks for a given type" do
      let(:event_type) { :update }

      it { is_expected.to eq([]) }
    end
  end
end
