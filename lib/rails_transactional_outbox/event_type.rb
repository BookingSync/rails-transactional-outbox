# frozen_string_literal: true

class RailsTransactionalOutbox
  class EventType
    EVENT_TYPES = %i[create update destroy].freeze
    EVENT_NAME_SUFFIXES = %w[created updated destroyed].freeze
    private_constant :EVENT_TYPES, :EVENT_NAME_SUFFIXES

    def self.resolve_from_event_name(event_name)
      EVENT_TYPES.find(-> { raise "unknown event type: #{event_name}" }) do |event_type|
        event_name.to_s.end_with?(new(event_type).event_name_suffix)
      end
    end

    attr_reader :event_type
    private     :event_type

    def initialize(event_type)
      @event_type = event_type.to_sym
    end

    def to_sym
      event_type
    end

    def event_name_suffix
      EVENT_TYPES
        .zip(EVENT_NAME_SUFFIXES)
        .to_h
        .fetch(event_type) { raise "unknown event type: #{event_type}" }
    end

    def destroy?
      event_type == :destroy
    end
  end
end
