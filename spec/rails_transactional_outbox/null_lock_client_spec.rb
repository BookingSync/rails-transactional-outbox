# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::NullLockClient do
  describe ".lock" do
    subject(:lock) do
      payload = {}
      described_class.lock(resource_key, expiration_time) do |yielded_payload|
        payload = yielded_payload
      end
      payload
    end

    let(:resource_key) { "resource_key" }
    let(:expiration_time) { 1 }

    it { is_expected.to eq(validity: expiration_time, resource: resource_key, value: "null_lock_client_lock") }
  end
end
