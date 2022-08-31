# frozen_string_literal: true

class RailsTransactionalOutbox
  module ReliableModel
    class ReliableCallback
      attr_reader :callback, :options
      private     :callback, :options

      def initialize(callback, options)
        @callback = callback
        @options = options
      end

      def for_event?(event_type)
        on.include?(event_type.to_sym)
      end

      def call(model)
        return unless execute?(model)

        model.instance_exec(&callback)
      end

      private

      def on
        Array(options.fetch(:on, [])).map(&:to_sym)
      end

      def execute?(model)
        if options.key?(:if)
          model.instance_exec(&options[:if])
        elsif options.key?(:unless)
          !model.instance_exec(&options[:unless])
        else
          true
        end
      end
    end
  end
end
