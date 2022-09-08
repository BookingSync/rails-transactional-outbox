# frozen_string_literal: true

class RailsTransactionalOutbox
  module OutboxModel
    extend ActiveSupport::Concern

    included do
      scope :fetch_processable, lambda { |batch_size|
        processable_now
          .lock("FOR UPDATE SKIP LOCKED")
          .order(created_at: :asc)
          .limit(batch_size)
      }

      scope :fetch_processable_for_causality_key, lambda { |batch_size, causality_key|
        processable_now
          .where(causality_key: causality_key)
          .order(created_at: :asc)
          .limit(batch_size)
      }

      scope :processable_now, lambda {
        where(processed_at: nil)
          .where("retry_at IS NULL OR retry_at <= ?", Time.current)
      }

      def self.unprocessed_causality_keys
        processable_now
          .select("causality_key")
          .distinct
          .pluck(:causality_key)
      end

      def self.any_records_to_process?
        processable_now.exists?
      end

      def self.mark_as_processed(processed_records)
        where(id: processed_records).update_all(processed_at: Time.current, error_class: nil, error_message: nil,
          failed_at: nil, retry_at: nil)
      end

      def self.outbox_encrypt_json_for(*encryptable_json_attributes)
        encryptable_json_attributes.each do |attribute|
          define_method "#{attribute}=" do |payload|
            super(payload.to_json)
          end

          define_method "transformed_#{attribute}" do
            JSON.parse(public_send(attribute)).symbolize_keys
          end
        end
      end
    end

    def transformed_arguments
      arguments.to_h.symbolize_keys
    end

    def transformed_changeset
      changeset.to_h.symbolize_keys
    end

    def processed?
      processed_at.present?
    end

    def failed?
      failed_at.present?
    end

    def handle_error(raised_error, clock: Time, backoff_multiplier: 5)
      @error = raised_error
      self.error_class = raised_error.class
      self.error_message = raised_error.message
      self.failed_at = clock.current
      self.attempts ||= 0
      self.attempts += 1
      self.retry_at = clock.current.advance(
        seconds: RailsTransactionalOutbox::ExponentialBackoff.backoff_for(backoff_multiplier, attempts)
      )
    end

    def error
      @error || error_class.constantize.new(error_message)
    end

    def event_type
      RailsTransactionalOutbox::EventType.resolve_from_event_name(event_name).to_sym
    end

    def infer_model
      model_klass = resource_class.constantize
      model_klass.find(resource_id)
    rescue ActiveRecord::RecordNotFound
      model_klass.new(id: resource_id) if RailsTransactionalOutbox::EventType.new(event_type).destroy?
    end
  end
end
