# frozen_string_literal: true

class RailsTransactionalOutbox
  module Tracers
    class NullTracer
      def self.trace(_event_name); end
    end
  end
end
