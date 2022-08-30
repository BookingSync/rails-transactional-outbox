#!/usr/bin/env ruby

require "bundler/setup"
require_relative "../lib/rails_transactional_outbox"

result = RailsTransactionalOutbox::HealthCheck.check
if result.empty?
  exit 0
else
  RailsTransactionalOutbox.configuration.logger.fatal "[Rails Transactional Outbox Worker] health check failed: #{result}"
  exit 1
end
