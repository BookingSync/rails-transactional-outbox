# frozen_string_literal: true

class RailsTransactionalOutbox
  class Configuration
    attr_accessor :database_connection_provider, :logger, :outbox_model, :transaction_provider
    attr_writer :error_handler, :transactional_outbox_worker_sleep_seconds, :outbox_batch_size

    def error_handler
      @error_handler || RailsTransactionalOutbox::ErrorHandlers::NullErrorHandler
    end

    def transactional_outbox_worker_sleep_seconds
      @transactional_outbox_worker_sleep_seconds || 0.5
    end

    def outbox_batch_size
      @outbox_batch_size || 100
    end

    def record_processors
      @record_processors ||= [RailsTransactionalOutbox::RecordProcessors::ActiveRecordProcessor.new]
    end

    def add_record_processor(record_processor)
      record_processors << record_processor
    end
  end
end
