# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::RecordProcessor do
  describe "#call" do
    subject(:call) { described_class.new.call(record) }

    let(:record) { OutboxEntry.new(context: record_context, id: 123) }

    context "when the record processors are found that would be applicable to a given record" do
      let(:record_context) { "special" }
      let(:test_record_processor) do
        Class.new(RailsTransactionalOutbox::RecordProcessors::BaseProcessor) do
          def applies?(_record)
            true
          end

          def call(record)
            record.context = "updated_from_processor"
          end
        end.new
      end
      let(:another_test_record_processor) do
        Class.new(RailsTransactionalOutbox::RecordProcessors::BaseProcessor) do
          def applies?(_record)
            true
          end

          def call(record)
            record.context += "_another_update"
          end
        end.new
      end

      before do
        RailsTransactionalOutbox.configure do |config|
          config.add_record_processor(test_record_processor)
          config.add_record_processor(another_test_record_processor)
        end
      end

      it "handles the processing via all applicable processors" do
        expect do
          call
        end.to change { record.context }.from("special").to("updated_from_processor_another_update")
      end
    end

    context "when the record processor is not found that would be applicable to a given record" do
      let(:record_context) { "operations" }
      let(:error_message) { "no processor was found for record with ID: 123, context: operations" }

      it { is_expected_block.to raise_error error_message }
    end
  end
end
