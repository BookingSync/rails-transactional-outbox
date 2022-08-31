# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::OutboxEntriesProcessor, :freeze_time do
  describe "#call" do
    subject(:call) { described_class.new.call }

    let!(:outbox_record_1) do
      OutboxEntry.create(event_name: event_name, context: "", processed_at: processed_at_1, created_at: Time.current,
        error_class: "StandardError", error_message: "message", failed_at: 1.week.ago,
        retry_at: 1.week.ago)
    end
    let!(:outbox_record_2) do
      OutboxEntry.create(event_name: event_name, context: "", processed_at: processed_at_2, created_at: 1.week.ago)
    end
    let(:event_name) { "example_resource_created" }
    let(:test_record_processor) do
      Class.new(RailsTransactionalOutbox::RecordProcessors::BaseProcessor) do
        def applies?(_record)
          true
        end

        def call(record)
          record.update!(context: "updated_from_processor")
        end
      end.new
    end
    let(:database_connection_provider) { ActiveRecord::Base }
    let(:transaction_provider) { ActiveRecord::Base }

    before do
      RailsTransactionalOutbox.configure do |config|
        config.database_connection_provider = database_connection_provider
        config.transaction_provider = transaction_provider
        config.outbox_model = OutboxEntry
        config.add_record_processor(test_record_processor)
      end
    end

    describe "when there are some outbox entries to be processed" do
      let(:processed_at_1) { nil }
      let(:processed_at_2) { nil }

      context "when success" do
        it "marks entries as processed" do
          expect do
            call
          end.to change { outbox_record_1.reload.processed_at }.from(nil).to(Time.current)
            .and change { outbox_record_2.reload.processed_at }.from(nil).to(Time.current)
            .and change { outbox_record_1.error_class }.to(nil)
            .and change { outbox_record_1.error_message }.to(nil)
            .and change { outbox_record_1.failed_at }.to(nil)
            .and change { outbox_record_1.retry_at }.to(nil)
        end

        it "handles the actual processing via a processor" do
          expect do
            call
          end.to change { outbox_record_1.reload.context }.from("").to("updated_from_processor")
            .and change { outbox_record_2.reload.context }.from("").to("updated_from_processor")
        end

        it "returns the processed records" do
          expect(call).to eq [outbox_record_2, outbox_record_1]
        end

        context "when the block is passed" do
          subject(:call) do
            described_class.new.call { |record| record.update!(updated_at: 10.days.from_now) }
          end

          it "yields the block upon processing" do
            expect do
              call
            end.to change { outbox_record_1.reload.updated_at }.to(10.days.from_now)
              .and change { outbox_record_2.reload.updated_at }.to(10.days.from_now)
          end
        end
      end

      context "when failure" do
        before do
          allow(test_record_processor).to receive(:call).and_call_original
          allow(test_record_processor).to receive(:call)
            .with(outbox_record_2).and_raise(StandardError.new("something went wrong"))
        end

        it "marks only successful entries as processed" do
          expect do
            call
          end.to change { outbox_record_1.reload.processed_at }.from(nil).to(Time.current)
            .and avoid_changing { outbox_record_2.reload.processed_at }
            .and change { outbox_record_1.error_class }.to(nil)
            .and change { outbox_record_1.error_message }.to(nil)
            .and change { outbox_record_1.failed_at }.to(nil)
            .and change { outbox_record_1.retry_at }.to(nil)
        end

        it "handles the actual processing via a processor for successful entries" do
          expect do
            call
          end.to change { outbox_record_1.reload.context }.from("").to("updated_from_processor")
            .and avoid_changing { outbox_record_2.reload.context }
        end

        it "returns the records" do
          expect(call).to eq [outbox_record_2, outbox_record_1]
        end

        context "when the block is passed" do
          subject(:call) do
            described_class.new.call { |record| record.update!(updated_at: 10.days.from_now) }
          end

          it "yields the block upon processing" do
            expect do
              call
            end.to change { outbox_record_1.reload.updated_at }.to(10.days.from_now)
              .and change { outbox_record_2.reload.updated_at }.to(10.days.from_now)

            expect(outbox_record_2.error.to_s).to eq "something went wrong"
          end
        end
      end
    end

    describe "when there are no outbox entries to be processed" do
      let(:processed_at_1) { 1.week.ago }
      let(:processed_at_2) { 1.week.ago }

      before do
        allow(transaction_provider).to receive(:transaction).and_yield
      end

      it "does not process any outbox entries" do
        expect do
          call
        end.to avoid_changing { outbox_record_1.reload.processed_at }
          .and avoid_changing { outbox_record_2.reload.processed_at }
      end

      it "returns early" do
        call

        expect(transaction_provider).not_to have_received(:transaction)
      end
    end
  end
end
