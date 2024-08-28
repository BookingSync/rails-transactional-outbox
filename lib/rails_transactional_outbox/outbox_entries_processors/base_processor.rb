# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessors
    class BaseProcessor
      attr_reader :config
      private     :config

      def initialize(config: RailsTransactionalOutbox.configuration)
        @config = config
      end

      def call(&)
        return [] unless outbox_model.any_records_to_process?

        execute(&)
      end

      private

      delegate :outbox_model, :outbox_batch_size, to: :config

      def execute(&)
        raise "implement me"
      end

      def process_records(records_to_process, &block)
        failed_records = []
        records_to_process.each do |record|
          begin
            process(record)
          rescue => e
            record.handle_error(e)
            record.save!
            failed_records << record
          end
          yield record if block
        end
        processed_records = records_to_process - failed_records
        mark_as_processed(processed_records)
      end

      def process(record)
        record_processor.call(record)
      end

      def record_processor
        @record_processor ||= RailsTransactionalOutbox::RecordProcessor.new
      end

      def mark_as_processed(processed_records)
        outbox_model.mark_as_processed(processed_records)
      end
    end
  end
end
