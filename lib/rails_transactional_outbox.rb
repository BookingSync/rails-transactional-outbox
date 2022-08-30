# frozen_string_literal: true

require "zeitwerk"
require "logger"
require "dry-monitor"
require "sigurd"
require "concurrent-ruby"

class RailsTransactionalOutbox
  def self.loader
    @loader ||= Zeitwerk::Loader.for_gem.tap do |loader|
      loader.ignore(
        "#{__dir__}/rails-transactional-outbox.rb",
        "#{__dir__}/tracers/datadog_tracer.rb"
      )
    end
  end

  def self.configuration
    @configuration ||= RailsTransactionalOutbox::Configuration.new
  end

  def self.configure
    yield configuration
  end

  def self.monitor
    @monitor ||= RailsTransactionalOutbox::Monitor.new
  end

  def self.reset
    @configuration = nil
  end

  def self.outbox_worker_health_check
    @outbox_worker_health_check ||= RailsTransactionalOutbox::HealthCheck.new
  end

  def self.enable_outbox_worker_healthcheck
    monitor.subscribe("rails_transactional_outbox.started") { outbox_worker_health_check.register_heartbeat }
    monitor.subscribe("rails_transactional_outbox.stopped") { outbox_worker_health_check.worker_stopped }
    monitor.subscribe("rails_transactional_outbox.heartbeat") { outbox_worker_health_check.register_heartbeat }
  end

  def self.start_outbox_worker(threads_number: 1)
    runners = (1..threads_number).map { RailsTransactionalOutbox::Runner.new(config: configuration) }
    executor = Sigurd::Executor.new(runners, sleep_seconds: 5, logger: configuration.logger)
    signal_handler = Sigurd::SignalHandler.new(executor)
    signal_handler.run!
  end
end

RailsTransactionalOutbox.loader.setup
