# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::OutboxEntryFactory, :freeze_time do
  describe "#build", :freeze_time do
    subject(:build) { described_class.new.build(model, event_type) }

    let(:model) { User.create(name: "name") }
    let(:expected_changeset) do
      {
        "created_at" => [nil, Time.current.as_json],
        "updated_at" => [nil, Time.current.as_json],
        "id" => [nil, model.id],
        "name" => [nil, "name"]
      }
    end

    before do
      RailsTransactionalOutbox.configure do |config|
        config.outbox_model = OutboxEntry
        config.outbox_entry_causality_key_resolver = ->(model) { model.class.to_s }
      end
    end

    context "when event_type is :create" do
      let(:event_type) { :create }

      it "returns a new outbox entry" do
        expect(build).to be_a(OutboxEntry)
        expect(build).not_to be_persisted
        expect(build.resource_id).to eq model.id.to_s
        expect(build.resource_class).to eq "User"
        expect(build.changeset).to eq expected_changeset
        expect(build.event_name).to eq "user_created"
        expect(build.causality_key).to eq "User"
      end
    end

    context "when event_type is :update" do
      let(:event_type) { :update }

      it "returns a new outbox entry" do
        expect(build).to be_a(OutboxEntry)
        expect(build).not_to be_persisted
        expect(build.resource_id).to eq model.id.to_s
        expect(build.resource_class).to eq "User"
        expect(build.changeset).to eq expected_changeset
        expect(build.event_name).to eq "user_updated"
        expect(build.causality_key).to eq "User"
      end
    end

    context "when event_type is :destroy" do
      let(:event_type) { :destroy }

      it "returns a new outbox entry" do
        expect(build).to be_a(OutboxEntry)
        expect(build).not_to be_persisted
        expect(build.resource_id).to eq model.id.to_s
        expect(build.resource_class).to eq "User"
        expect(build.changeset).to eq expected_changeset
        expect(build.event_name).to eq "user_destroyed"
        expect(build.causality_key).to eq "User"
      end
    end

    context "when event_type is something else" do
      let(:event_type) { :other }

      it { is_expected_block.to raise_error "unknown event type: other" }
    end
  end
end
