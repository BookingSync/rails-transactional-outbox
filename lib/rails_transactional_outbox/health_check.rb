# frozen_string_literal: true

require "redis"

class RailsTransactionalOutbox
  class HealthCheck
    KEY_PREFIX = "__rails_transactional__outbox_worker__running__"
    VALUE = "OK"
    private_constant :KEY_PREFIX, :VALUE

    def self.check(redis_url: ENV.fetch("REDIS_URL", nil), hostname: ENV.fetch("HOSTNAME", nil),
      expiry_time_in_seconds: 120)
      new(redis_url: redis_url, hostname: hostname, expiry_time_in_seconds: expiry_time_in_seconds).check
    end

    attr_reader :redis_client, :hostname, :expiry_time_in_seconds

    def initialize(redis_url: ENV.fetch("REDIS_URL", nil), hostname: ENV.fetch("HOSTNAME", nil),
      expiry_time_in_seconds: 120)
      @redis_client = Redis.new(url: redis_url)
      @hostname = hostname
      @expiry_time_in_seconds = expiry_time_in_seconds
    end

    def check
      value = redis_client.get(key)
      if value == VALUE
        ""
      else
        "[Rails Transactional Outbox Worker - expected #{VALUE} under #{key}, found: #{value}] "
      end
    end

    def register_heartbeat
      redis_client.set(key, VALUE, ex: expiry_time_in_seconds)
    end

    def worker_stopped
      redis_client.del(key)
    end

    private

    def key
      "#{KEY_PREFIX}#{hostname}"
    end
  end
end
