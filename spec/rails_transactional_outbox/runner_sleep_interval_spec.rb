# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::RunnerSleepInterval do
  describe ".interval_for" do
    subject(:interval_for) { described_class.interval_for(entries, sleep_seconds, idle_delay_multiplier) }

    let(:sleep_seconds) { 1 }
    let(:idle_delay_multiplier) { 5 }

    context "when entries array is empty" do
      let(:entries) { [] }

      it { is_expected.to eq 5 }
    end

    context "when entries array is not empty" do
      let(:entries) { [double] }

      it { is_expected.to eq 1 }
    end
  end
end
