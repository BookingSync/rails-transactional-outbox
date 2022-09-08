# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessors
    class OrderedByCausalityKeyProcessor
      attr_reader :config
      private     :config

      def initialize(config: RailsTransactionalOutbox.configuration)
        @config = config
      end

      def call(&block)
        return [] unless outbox_model.any_records_to_process?

        unprocessed_causality_keys.each_with_object([]) do |causality_key, processed_records|
          lock_client.lock(lock_name(causality_key), lock_expiry_time) do |locked|
            next unless locked

            processed_records.concat(fetch_records(causality_key).tap { |records| process_records(records, &block) })
          end
        end
      end

      private

      delegate :outbox_model, :outbox_batch_size, :lock_client, :lock_expiry_time, to: :config

      def unprocessed_causality_keys
        outbox_model.unprocessed_causality_keys
      end

      def lock_name(causality_key)
        "RailsTransactionalOutbox-#{causality_key}"
      end

      def fetch_records(causality_key)
        outbox_model.fetch_processable_for_causality_key(outbox_batch_size, causality_key).to_a
      end

      def process_records(records_to_process, &block)
        failed_records = Concurrent::Array.new
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
