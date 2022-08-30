# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::RecordProcessors::ActiveRecordProcessor do
  describe ".context" do
    subject(:context) { described_class.context }

    it { is_expected.to eq "active_record" }
  end

  describe "#applies?" do
    subject(:processor) { described_class.new.applies?(record) }

    let(:record) { OutboxEntry.new(context: record_context) }

    context "when the record's context is 'active_record'" do
      let(:record_context) { "active_record" }

      it { is_expected.to be true }
    end

    context "when the record's context is not 'active_record'" do
      let(:record_context) { "operations" }

      it { is_expected.to be false }
    end
  end

  describe "#call", :freeze_time, :require_outbox_model do
    subject(:call) { described_class.new.call(record) }

    let(:record) do
      OutboxEntry.new(resource_id: resource_id, resource_class: "User", changeset: changeset,
        event_name: "user_created", id: 123)
    end
    let(:changeset) do
      {
        "name" => ["old name", "current name"]
      }
    end
    let(:resource) { User.create!(name: "current name") }

    let(:reliable_callback_1) do
      RailsTransactionalOutbox::ReliableModel::ReliableCallback.new(
        -> { update!(name: previous_changes[:name][0]) }, on: :create
      )
    end
    let(:reliable_callback_2) do
      RailsTransactionalOutbox::ReliableModel::ReliableCallback.new(
        -> { update!(updated_at: 1.week.from_now) }, on: :create
      )
    end
    let(:non_applicable_reliable_callback) do
      RailsTransactionalOutbox::ReliableModel::ReliableCallback.new(double, on: :update)
    end
    let(:registry) do
      RailsTransactionalOutbox::ReliableModel::ReliableCallbacksRegistry.new
    end

    before do
      allow(User).to receive(:reliable_after_commit_callbacks).and_return(registry)
      registry << reliable_callback_1
      registry << reliable_callback_2
      registry << non_applicable_reliable_callback
    end

    context "when the model can be inferred" do
      let(:resource_id) { resource.id }

      it "executes all applicable callbacks" do
        expect do
          call
        end.to change { resource.reload.name }.from("current name").to("old name")
          .and change { resource.updated_at }.from(Time.current).to(1.week.from_now)
      end
    end

    context "when the model cannot be inferred" do
      let(:resource_id) { "unknown" }

      it { is_expected_block.to raise_error "could not find model for outbox record: 123" }
    end
  end
end
