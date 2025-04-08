# frozen_string_literal: true

class RailsTransactionalOutbox
  module Tracers
    class DatadogTracer
      SERVICE_NAME = "rails_transactional_outbox_worker"
      private_constant :SERVICE_NAME

      def self.service_name
        SERVICE_NAME
      end

      def trace(event_name)
        tracer.trace(event_name, span_type_key => "worker", service: self.class.service_name,
          on_error: error_handler) do |_span|
          yield
        end
      end

      private

      def tracer
        if Datadog.respond_to?(:tracer)
          Datadog.tracer
        else
          Datadog::Tracing
        end
      end

      def span_type_key
        if defined?(DDTrace)
          :span_type
        else
          :type
        end
      end

      def error_handler
        ->(span, error) { span.set_error(error) }
      end
    end
  end
end
