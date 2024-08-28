# frozen_string_literal: true

class RailsTransactionalOutbox
  class DatadogLatencyReporter
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def report(latency: generate_latency)
      datadog_statsd_client.gauge("rails_transactional_outbox.latency.minimum", latency.minimum)
      datadog_statsd_client.gauge("rails_transactional_outbox.latency.maximum", latency.maximum)
      datadog_statsd_client.gauge("rails_transactional_outbox.latency.average", latency.average)
      datadog_statsd_client.gauge("rails_transactional_outbox.latency.highest_since_creation_date",
        latency.highest_since_creation_date)
    end

    private

    delegate :datadog_statsd_client, :datadog_statsd_prefix, to: :config

    def generate_latency
      RailsTransactionalOutbox::LatencyTracker.new.calculate
    end
  end
end
