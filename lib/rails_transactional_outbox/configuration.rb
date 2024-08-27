# frozen_string_literal: true

class RailsTransactionalOutbox
  class Configuration
    attr_accessor :database_connection_provider, :logger, :outbox_model, :transaction_provider, :datadog_statsd_client
    attr_writer :error_handler, :transactional_outbox_worker_sleep_seconds,
      :transactional_outbox_worker_idle_delay_multiplier, :outbox_batch_size, :outbox_entries_processor,
      :lock_client, :lock_expiry_time, :outbox_entry_causality_key_resolver,
      :raise_not_found_model_error, :unprocessed_causality_keys_limit, :high_priority_sidekiq_queue

    def self.high_priority_sidekiq_queue
      :rails_transactional_outbox_high_priority
    end

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
      return @raise_not_found_model_error if defined?(@raise_not_found_model_error)

      true
    end

    alias_method :raise_not_found_model_error?, :raise_not_found_model_error

    def lock_client
      @lock_client || RailsTransactionalOutbox::NullLockClient
    end

    def lock_expiry_time
      @lock_expiry_time || 10_000
    end

    def outbox_entry_causality_key_resolver
      @outbox_entry_causality_key_resolver || ->(_model) {}
    end

    def unprocessed_causality_keys_limit
      return @unprocessed_causality_keys_limit.to_i if defined?(@unprocessed_causality_keys_limit)

      10_000
    end

    def high_priority_sidekiq_queue
      return @high_priority_sidekiq_queue if defined?(@high_priority_sidekiq_queue)

      self.class.high_priority_sidekiq_queue
    end
  end
end
