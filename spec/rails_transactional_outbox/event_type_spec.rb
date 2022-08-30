# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::EventType do
  describe ".resolve_from_event_name" do
    subject(:resolve_from_event_name) { described_class.resolve_from_event_name(event_name).to_sym }

    context "when event_name is ends_with _created suffix" do
      let(:event_name) { "resource_created" }

      it { is_expected.to eq :create }
    end

    context "when event_name is ends_with _updated suffix" do
      let(:event_name) { "resource_updated" }

      it { is_expected.to eq :update }
    end

    context "when event_name is ends_with _destroyed suffix" do
      let(:event_name) { "resource_destroyed" }

      it { is_expected.to eq :destroy }
    end

    context "when event_name is something else" do
      let(:event_name) { "resource_changed" }

      it { is_expected_block.to raise_error "unknown event type: resource_changed" }
    end

    context "when event_name is nil" do
      let(:event_name) { nil }

      it { is_expected_block.to raise_error "unknown event type: " }
    end
  end

  describe "#event_name_suffix" do
    subject(:event_name_suffix) { described_class.new(event_type).event_name_suffix }

    context "when event_type is :create" do
      let(:event_type) { :create }

      it { is_expected.to eq "created" }
    end

    context "when event_type is :update" do
      let(:event_type) { :update }

      it { is_expected.to eq "updated" }
    end

    context "when event_type is :destroy" do
      let(:event_type) { :destroy }

      it { is_expected.to eq "destroyed" }
    end

    context "when event_type is something else" do
      let(:event_type) { :other }

      it { is_expected_block.to raise_error "unknown event type: other" }
    end
  end

  describe "#to_sym" do
    subject(:to_sym) { described_class.new("create").to_sym }

    it { is_expected.to eq :create }
  end

  describe "#destroy?" do
    subject(:destroy?) { described_class.new(event_type).destroy? }

    context "when event_type is destroy" do
      let(:event_type) { "destroy" }

      it { is_expected.to be true }
    end

    context "when event_type is not destroy" do
      let(:event_type) { "update" }

      it { is_expected.to be false }
    end
  end
end
