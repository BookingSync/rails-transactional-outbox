# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntryFactory
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def build(model, event_type)
      outbox_model.new(attributes_for_entry(model, event_type))
    end

    private

    delegate :outbox_model, :outbox_entry_causality_key_resolver, to: :config

    def attributes_for_entry(model, event_type)
      {
        resource_class: model.class.to_s,
        resource_id: model.id,
        changeset: model.saved_changes,
        event_name: "#{model.model_name.singular}_#{event_name_suffix(event_type)}",
        context: RailsTransactionalOutbox::RecordProcessors::ActiveRecordProcessor.context,
        causality_key: outbox_entry_causality_key_resolver.call(model)
      }.compact
    end

    def event_name_suffix(event_type)
      RailsTransactionalOutbox::EventType.new(event_type).event_name_suffix
    end
  end
end
