# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessor
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def call
      transaction do
        outbox_model.fetch_processable(outbox_batch_size).to_a.tap do |records_to_process|
          failed_records = Concurrent::Array.new
          # TODO: considering adding internal threads for better efficiency, these are just IO operations
          # that don't require ordering of any kind
          records_to_process.each do |record|
            begin
              process(record)
            rescue => e
              record.handle_error(e)
              record.save!
              failed_records << record
            end
            yield record if block_given?
          end
          processed_records = records_to_process - failed_records
          mark_as_processed(processed_records)
        end
      end
    end

    private

    delegate :outbox_model, :outbox_batch_size, :transaction_provider, to: :config
    delegate :transaction, to: :transaction_provider

    def mark_as_processed(processed_records)
      outbox_model
        .where(id: processed_records)
        .update_all(processed_at: Time.current, error_class: nil, error_message: nil,
          failed_at: nil, retry_at: nil)
    end

    def process(record)
      record_processor.call(record)
    end

    def record_processor
      @record_processor ||= RailsTransactionalOutbox::RecordProcessor.new
    end
  end
end
