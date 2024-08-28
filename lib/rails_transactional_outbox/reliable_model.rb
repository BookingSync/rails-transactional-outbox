# frozen_string_literal: true

class RailsTransactionalOutbox
  module ReliableModel
    extend ActiveSupport::Concern

    NOT_PROVIDED = Object.new.freeze
    private_constant :NOT_PROVIDED

    included do
      after_create :transactional_outbox_insert_model_created
      after_update :transactional_outbox_insert_model_updated
      after_destroy :transactional_outbox_insert_model_destroyed

      def self.reliable_after_commit_callbacks
        @reliable_after_commit_callbacks ||= RailsTransactionalOutbox::ReliableModel::ReliableCallbacksRegistry.new
      end

      def self.reliable_after_commit(method_name = NOT_PROVIDED, options = {}, &block)
        if block
          callback_proc = block
        else
          raise ArgumentError.new("You must provide a block or a method name") unless method_name.is_a?(Symbol)

          callback_proc = -> { send(method_name) }
        end

        final_options = options.reverse_merge(on: %i[create update destroy])
        reliable_after_commit_callbacks << ReliableCallback.new(callback_proc, final_options)
      end

      def self.reliable_after_create_commit(method_name = NOT_PROVIDED, options = {}, &)
        reliable_after_commit(method_name, options.merge(on: :create), &)
      end

      def self.reliable_after_update_commit(method_name = NOT_PROVIDED, options = {}, &)
        reliable_after_commit(method_name, options.merge(on: :update), &)
      end

      def self.reliable_after_destroy_commit(method_name = NOT_PROVIDED, options = {}, &)
        reliable_after_commit(method_name, options.merge(on: :destroy), &)
      end

      def self.reliable_after_save_commit(method_name = NOT_PROVIDED, options = {}, &)
        reliable_after_commit(method_name, options.merge(on: %i[create update]), &)
      end

      alias_method :original_previous_changes, :previous_changes

      def previous_changes
        @previous_changes || original_previous_changes
      end

      def previous_changes=(changeset)
        @previous_changes = changeset
      end

      private

      def transactional_outbox_insert_model_created
        transactional_outbox_entry_factory.build(self, :create).save
      end

      def transactional_outbox_insert_model_updated
        transactional_outbox_entry_factory.build(self, :update).save!
      end

      def transactional_outbox_insert_model_destroyed
        transactional_outbox_entry_factory.build(self, :destroy).save!
      end

      def transactional_outbox_entry_factory
        @transactional_outbox_entry_factory ||= RailsTransactionalOutbox::OutboxEntryFactory.new
      end
    end

    def reliable_after_commit_callbacks
      self.class.reliable_after_commit_callbacks
    end
  end
end
