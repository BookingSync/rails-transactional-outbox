# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::ErrorHandlers::NullErrorHandler do
  describe ".capture_exception" do
    subject(:capture_exception) { described_class.capture_exception(error) }

    let(:error) { double }

    it "does nothing" do
      expect do
        capture_exception
      end.not_to raise_error
    end
  end
end
