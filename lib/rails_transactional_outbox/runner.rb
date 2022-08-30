# frozen_string_literal: true

class RailsTransactionalOutbox
  class Runner
    attr_reader :config, :id
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @id = SecureRandom.uuid
      @config = config
      logger.push_tags("RailsTransactionalOutbox::Runner #{id}") if logger.respond_to?(:push_tags)
    end

    def start
      log("started")
      instrument("rails_transactional_outbox.started")
      @should_stop = false
      ensure_database_connection!
      loop do
        if @should_stop
          instrument("rails_transactional_outbox.shutting_down")
          log("shutting down")
          break
        end
        process_entries
        instrument("rails_transactional_outbox.heartbeat")
        # TODO: maybe apply some backoff or longer pause if there were no entries to be processed?
        # doesn't make much sense to keep querying the DB if there is nothing there
        sleep transactional_outbox_worker_sleep_seconds
      end
    rescue => e
      error_handler.capture_exception(e)
      log("error: #{e} #{e.message}")
      instrument("rails_transactional_outbox.error", error: e, error_message: e.message)
      raise e
    end

    def stop
      log("Rails Transactional Outbox Worker stopping")
      instrument("rails_transactional_outbox.stopped")
      @should_stop = true
    end

    private

    delegate :error_handler, :transactional_outbox_worker_sleep_seconds, :database_connection_provider,
      :logger, to: :config
    delegate :monitor, to: RailsTransactionalOutbox

    def process_entries
      tracer.trace("rails_transactional_outbox_entries_processor") do
        outbox_entries_processor.call do |record|
          if record.failed?
            instrument("rails_transactional_outbox.record_processing_failed", outbox_record: record)
            error("failed to process #{record.inspect}")
            error_handler.capture_exception(record.error)
          else
            debug("processed #{record.inspect}")
            instrument("rails_transactional_outbox.record_processed", outbox_record: record)
          end
        end
      end
    end

    def ensure_database_connection!
      database_connection_provider.connection.reconnect!
    end

    def outbox_entries_processor
      @outbox_entries_processor ||= RailsTransactionalOutbox::OutboxEntriesProcessor.new
    end

    def log(message)
      logger.info("#{log_prefix} #{message}")
    end

    def debug(message)
      logger.debug("#{log_prefix} #{message}")
    end

    def error(message)
      logger.error("#{log_prefix} #{message}")
    end

    def log_prefix
      "[Rails Transactional Outbox Worker] "
    end

    def instrument(*args, **kwargs)
      monitor.instrument(*args, **kwargs) do
        yield if block_given?
      end
    end

    def tracer
      @tracer ||= if Object.const_defined?(:Datadog)
        RailsTransactionalOutbox::Tracers::DatadogTracer.new
      else
        RailsTransactionalOutbox::Tracers::NullTracer
      end
    end
  end
end
