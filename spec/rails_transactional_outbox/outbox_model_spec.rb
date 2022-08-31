# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::OutboxModel do
  describe ".fetch_processable" do
    subject(:fetch_processable) { OutboxEntry.fetch_processable(batch_size).to_a }

    let(:batch_size) { 2 }
    let(:event_name) { "example_resource_created" }

    let!(:outbox_record_1) do
      OutboxEntry.create(event_name: event_name, created_at: 1.week.from_now, context: "")
    end
    let!(:outbox_record_2) do
      OutboxEntry.create(event_name: event_name, created_at: 2.weeks.ago, context: "")
    end
    let!(:outbox_record_3) do
      OutboxEntry.create(event_name: event_name, created_at: 1.month.ago, retry_at: 1.minute.ago, context: "")
    end
    let!(:outbox_record_4) do
      OutboxEntry.create(event_name: event_name, created_at: 2.year.ago, processed_at: 1.year.ago, context: "")
    end
    let!(:outbox_record_5) do
      OutboxEntry.create(event_name: event_name, created_at: 1.month.ago, retry_at: 1.day.from_now, context: "")
    end

    before do
      OutboxEntry.where.not(
        id: [outbox_record_1, outbox_record_2, outbox_record_3, outbox_record_4, outbox_record_5]
      ).delete_all
    end

    it "returns sorted non-processed records up to a given limit
    that are supposed to be retried now if they failed previously" do
      expect(fetch_processable).to eq([outbox_record_3, outbox_record_2])
    end

    describe "locking" do
      let(:collection) { OutboxEntry }

      before do
        allow_any_instance_of(ActiveRecord::Relation).to receive(:where).and_return(collection)
        allow(collection).to receive(:lock).and_call_original
      end

      it "uses locking to prevent concurrent access" do
        fetch_processable

        expect(collection).to have_received(:lock).with("FOR UPDATE SKIP LOCKED")
      end
    end
  end

  describe ".any_records_to_process?" do
    subject(:any_records_to_process?) { OutboxEntry.any_records_to_process? }

    let(:event_name) { "example_resource_created" }

    let!(:outbox_record_1) do
      OutboxEntry.create(event_name: event_name, created_at: 2.year.ago, processed_at: 1.year.ago, context: "")
    end
    let!(:outbox_record_2) do
      OutboxEntry.create(event_name: event_name, created_at: 1.month.ago, retry_at: 1.day.from_now, context: "")
    end

    context "when there are some records to process" do
      let!(:outbox_record_3) do
        OutboxEntry.create(event_name: event_name, created_at: 1.month.ago, retry_at: 1.minute.ago, context: "")
      end

      before do
        OutboxEntry.where.not(id: [outbox_record_1, outbox_record_2, outbox_record_3]).delete_all
      end

      it { is_expected.to be true }
    end

    context "when there are no records to process" do
      before do
        OutboxEntry.where.not(id: [outbox_record_1, outbox_record_2]).delete_all
      end

      it { is_expected.to be false }
    end
  end

  describe "transformed_changeset/changeset=" do
    subject(:transformed_changeset) { outbox_record.transformed_changeset }

    context "when the model handles changeset" do
      let(:changeset) { { "id" => 1, "name" => "name" } }

      context "when it handles it as jsonb" do
        let(:outbox_record) { OutboxEntry.new(changeset: changeset) }

        it { is_expected.to eq changeset.symbolize_keys }
      end

      context "when it handles it as encrypted text" do
        let(:outbox_record) { OutboxWithEncryptionEntry.new(changeset: changeset) }

        it { is_expected.to eq changeset.symbolize_keys }
      end
    end
  end

  describe "transformed_arguments/arguments=" do
    subject(:transformed_arguments) { outbox_record.transformed_arguments }

    context "when the model handles changeset" do
      let(:arguments) { { "id" => 1, "name" => "name" } }

      context "when it handles it as jsonb" do
        let(:outbox_record) { OutboxEntry.new(arguments: arguments) }

        it { is_expected.to eq arguments.symbolize_keys }
      end

      context "when it handles it as encrypted text" do
        let(:outbox_record) { OutboxWithEncryptionEntry.new(arguments: arguments) }

        it { is_expected.to eq arguments.symbolize_keys }
      end
    end
  end

  describe "#processed?" do
    subject(:processed?) { outbox_record.processed? }

    let(:outbox_record) { OutboxEntry.new(processed_at: processed_at) }

    context "when processed_at is present" do
      let(:processed_at) { Time.current }

      it { is_expected.to be true }
    end

    context "when processed_at is not present" do
      let(:processed_at) { nil }

      it { is_expected.to be false }
    end
  end

  describe "#failed?" do
    subject(:failed?) { outbox_record.failed? }

    let(:outbox_record) { OutboxEntry.new(failed_at: failed_at) }

    context "when failed_at is present" do
      let(:failed_at) { Time.current }

      it { is_expected.to be true }
    end

    context "when failed_at is not present" do
      let(:failed_at) { nil }

      it { is_expected.to be false }
    end
  end

  describe "#handle_error", :freeze_time do
    subject(:handle_error) { outbox_record.handle_error(error) }

    let(:outbox_record) { OutboxEntry.new(attempts: attempts) }
    let(:error) { StandardError.new("some error") }

    describe "general behavior" do
      let(:attempts) { 0 }

      it "sets error-related attributes" do
        expect do
          handle_error
        end.to change { outbox_record.error_class }.to("StandardError")
          .and change { outbox_record.error_message }.to("some error")
          .and change { outbox_record.failed_at }.to(Time.current)
          .and change { outbox_record.attempts }.to(1)
          .and change { outbox_record.retry_at }.to(10.seconds.from_now)
      end

      describe "assigning error" do
        let(:error) { error_class.new(message: "some error") }
        let(:error_class) do
          Class.new(StandardError) do
            def initialize(message:)
              super(message)
            end
          end
        end

        it "assigns @error instance variable" do
          handle_error

          expect(outbox_record.error).to eq error
        end
      end
    end

    context "when attempts is nil" do
      let(:attempts) { nil }

      it "sets :retry_at to be 10 seconds from now" do
        expect do
          handle_error
        end.to change { outbox_record.retry_at }.to(10.seconds.from_now)
      end
    end

    context "when attempts is 0" do
      let(:attempts) { 0 }

      it "sets :retry_at to be 10 seconds from now" do
        expect do
          handle_error
        end.to change { outbox_record.retry_at }.to(10.seconds.from_now)
      end
    end

    context "when attempts is 1" do
      let(:attempts) { 1 }

      it "sets :retry_at to be 20 seconds from now" do
        expect do
          handle_error
        end.to change { outbox_record.retry_at }.to(20.seconds.from_now)
      end
    end

    context "when attempts is 2" do
      let(:attempts) { 2 }

      it "sets :retry_at to be 40 seconds from now" do
        expect do
          handle_error
        end.to change { outbox_record.retry_at }.to(40.seconds.from_now)
      end
    end
  end

  describe "#error" do
    subject(:error) { outbox_record.error }

    let(:outbox_record) { OutboxEntry.new(error_class: "StandardError", error_message: "error message") }

    it { is_expected.to eq StandardError.new("error message") }
  end

  describe "#event_type" do
    subject(:event_type) { outbox_record.event_type }

    let(:outbox_record) { OutboxEntry.new(event_name: event_name) }

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

  describe "#infer_model", :require_outbox_model do
    subject(:infer_model) { record.infer_model }

    let(:record) { OutboxEntry.new(resource_class: "User", resource_id: user_id, event_name: event_name) }
    let!(:user) { User.create!(name: "name") }
    let(:user_id) { user.id }
    let(:event_name) { "resource_created" }

    context "when the model can be resolved by ID lookup" do
      it { is_expected.to eq user }
    end

    context "when the model cannot be resolved by ID lookup" do
      before do
        user.delete
      end

      context "when the event type is :destroy" do
        let(:event_name) { "resource_destroyed" }

        it { is_expected.to eq(User.new(id: user_id)) }
      end

      context "when the event type is not :destroy" do
        it { is_expected.to be_nil }
      end
    end
  end
end
