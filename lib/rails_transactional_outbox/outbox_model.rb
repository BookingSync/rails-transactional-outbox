# frozen_string_literal: true

class RailsTransactionalOutbox
  module OutboxModel
    extend ActiveSupport::Concern

    included do
      scope :fetch_processable, lambda { |batch_size|
        where(processed_at: nil)
          .lock("FOR UPDATE SKIP LOCKED")
          .where("retry_at IS NULL OR retry_at <= ?", Time.current)
          .order(created_at: :asc)
          .limit(batch_size)
      }

      def self.any_records_to_process?
        where(processed_at: nil)
          .where("retry_at IS NULL OR retry_at <= ?", Time.current)
          .exists?
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
