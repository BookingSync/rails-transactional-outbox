# frozen_string_literal: true

class RailsTransactionalOutbox
  class RecordProcessors
    class ActiveRecordProcessor < RailsTransactionalOutbox::RecordProcessors::BaseProcessor
      ACTIVE_RECORD_CONTEXT = "active_record"
      private_constant :ACTIVE_RECORD_CONTEXT

      def self.context
        ACTIVE_RECORD_CONTEXT
      end

      def applies?(record)
        record.context == ACTIVE_RECORD_CONTEXT
      end

      def call(record)
        model = record.infer_model or raise CouldNotFindModelError.new(record)
        model.previous_changes = record.changeset.with_indifferent_access
        model.reliable_after_commit_callbacks.for_event_type(record.event_type).each do |callback|
          callback.call(model)
        end
      end

      class CouldNotFindModelError < StandardError
        attr_reader :record

        def initialize(record)
          super()
          @record = record
        end

        def to_s
          "could not find model for outbox record: #{record.id}"
        end
      end
    end
  end
end
