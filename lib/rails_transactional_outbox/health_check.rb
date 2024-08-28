# frozen_string_literal: true

class RailsTransactionalOutbox
  class HealthCheck
    KEY_PREFIX = "__rails_transactional__outbox_worker__running__"
    TMP_DIR = "/tmp"
    private_constant :KEY_PREFIX, :TMP_DIR

    def self.check(hostname: ENV.fetch("HOSTNAME", nil), expiry_time_in_seconds: 120)
      new(hostname:, expiry_time_in_seconds:).check
    end

    attr_reader :hostname, :expiry_time_in_seconds

    def initialize(hostname: ENV.fetch("HOSTNAME", nil), expiry_time_in_seconds: 120)
      @hostname = hostname
      @expiry_time_in_seconds = expiry_time_in_seconds
    end

    def check
      if healthcheck_storage.running?
        ""
      else
        "[Rails Transactional Outbox Worker healthcheck failed]"
      end
    end

    def register_heartbeat
      healthcheck_storage.touch
    end

    def worker_stopped
      healthcheck_storage.remove
    end

    private

    def healthcheck_storage
      @healthcheck_storage ||= FileBasedHealthcheck.new(directory: TMP_DIR, filename: key,
        time_threshold: expiry_time_in_seconds)
    end

    def key
      "#{KEY_PREFIX}#{hostname}"
    end
  end
end
