# frozen_string_literal: true

class RailsTransactionalOutbox
  module ReliableModel
    class ReliableCallbacksRegistry
      include Enumerable

      delegate :each, to: :registry

      attr_reader :registry
      private     :registry

      def initialize
        @registry = []
      end

      def <<(item)
        registry << item
      end

      def for_event_type(event_type)
        registry.select { |cb| cb.for_event?(event_type) }
      end
    end
  end
end
