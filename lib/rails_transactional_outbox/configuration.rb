# frozen_string_literal: true

class RailsTransactionalOutbox
  class Configuration
    attr_accessor :database_connection_provider, :logger, :outbox_model, :transaction_provider
    attr_writer :error_handler, :transactional_outbox_worker_sleep_seconds,
      :transactional_outbox_worker_idle_delay_multiplier, :outbox_batch_size, :outbox_entries_processor,
      :lock_client, :lock_expiry_time, :outbox_entry_causality_key_resolver,
      :raise_not_found_model_error

    def error_handler
      @error_handler || RailsTransactionalOutbox::ErrorHandlers::NullErrorHandler
    end

    def transactional_outbox_worker_sleep_seconds
      @transactional_outbox_worker_sleep_seconds || 0.5
    end

    def transactional_outbox_worker_idle_delay_multiplier
      @transactional_outbox_worker_idle_delay_multiplier || 10
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

    def outbox_entries_processor
      @outbox_entries_processor ||= RailsTransactionalOutbox::OutboxEntriesProcessors::NonOrderedProcessor.new
    end

    def raise_not_found_model_error
      @raise_not_found_model_error.nil? ? true : @raise_not_found_model_error
    end

    def lock_client
      @lock_client || RailsTransactionalOutbox::NullLockClient
    end

    def lock_expiry_time
      @lock_expiry_time || 10_000
    end

    def outbox_entry_causality_key_resolver
      @outbox_entry_causality_key_resolver || ->(_model) {}
    end
  end
end
