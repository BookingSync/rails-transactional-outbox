# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessors
    class NonOrderedProcessor < RailsTransactionalOutbox::OutboxEntriesProcessors::BaseProcessor
      private

      delegate :transaction_provider, to: :config
      delegate :transaction, to: :transaction_provider

      def execute(&block)
        transaction do
          outbox_model.fetch_processable(outbox_batch_size).to_a.tap do |records_to_process|
            process_records(records_to_process, &block)
          end
        end
      end
    end
  end
end
