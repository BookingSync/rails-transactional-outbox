# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::ExponentialBackoff do
  describe ".backoff_for" do
    subject(:backoff_for) { described_class.backoff_for(multiplier, count) }

    let(:multiplier) { 5 }

    context "when the count is 0" do
      let(:count) { 0 }

      it { is_expected.to eq 5 }
    end

    context "when the count is 1" do
      let(:count) { 1 }

      it { is_expected.to eq 10 }
    end

    context "when the count is 2" do
      let(:count) { 2 }

      it { is_expected.to eq 20 }
    end

    context "when the count is 3" do
      let(:count) { 3 }

      it { is_expected.to eq 40 }
    end

    context "when the count is 4" do
      let(:count) { 4 }

      it { is_expected.to eq 80 }
    end

    context "when the count is 5" do
      let(:count) { 5 }

      it { is_expected.to eq 160 }
    end

    context "when the count is 6" do
      let(:count) { 6 }

      it { is_expected.to eq 320 }
    end

    context "when the count is 7" do
      let(:count) { 7 }

      it { is_expected.to eq 640 }
    end
  end
end
