# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessors
    class OrderedByCausalityKeyProcessor < RailsTransactionalOutbox::OutboxEntriesProcessors::BaseProcessor
      private

      delegate :lock_client, :lock_expiry_time, to: :config

      def execute(&block)
        unprocessed_causality_keys.each_with_object([]) do |causality_key, processed_records|
          lock_client.lock(lock_name(causality_key), lock_expiry_time) do |locked|
            next unless locked

            processed_records.concat(fetch_records(causality_key).tap { |records| process_records(records, &block) })
          end
        end
      end

      def unprocessed_causality_keys
        outbox_model.unprocessed_causality_keys
      end

      def lock_name(causality_key)
        "RailsTransactionalOutbox-#{causality_key}"
      end

      def fetch_records(causality_key)
        outbox_model.fetch_processable_for_causality_key(outbox_batch_size, causality_key).to_a
      end
    end
  end
end
