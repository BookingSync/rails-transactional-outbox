# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessor
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def call(&)
      config.outbox_entries_processor.call(&)
    end
  end
end
