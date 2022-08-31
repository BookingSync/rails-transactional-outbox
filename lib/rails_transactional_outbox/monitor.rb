# frozen_string_literal: true

class RailsTransactionalOutbox
  class Monitor < Dry::Monitor::Notifications
    EVENTS = %w[
      rails_transactional_outbox.started
      rails_transactional_outbox.stopped
      rails_transactional_outbox.shutting_down
      rails_transactional_outbox.record_processing_failed
      rails_transactional_outbox.record_processed
      rails_transactional_outbox.error
      rails_transactional_outbox.heartbeat
    ].freeze

    private_constant :EVENTS

    def initialize
      super(:rails_transactional_outbox)
      EVENTS.each { |event| register_event(event) }
    end

    def subscribe(event)
      return super if events.include?(event.to_s)

      raise UnknownEventError.new(events, event)
    end

    def events
      EVENTS
    end

    class UnknownEventError < StandardError
      attr_reader :available_events, :current_event
      private     :available_events, :current_event

      def initialize(available_events, current_event)
        super()
        @available_events = available_events
        @current_event = current_event
      end

      def message
        "unknown event: #{current_event}, the available events are: #{available_events.join(", ")}"
      end
    end
  end
end
