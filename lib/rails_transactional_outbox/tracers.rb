# frozen_string_literal: true

class RailsTransactionalOutbox
  module Tracers
    autoload :DatadogTracer, "rails_transactional_outbox/tracers/datadog_tracer"
  end
end
