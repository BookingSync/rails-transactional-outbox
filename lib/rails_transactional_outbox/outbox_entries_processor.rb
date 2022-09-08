# frozen_string_literal: true

class RailsTransactionalOutbox
  class OutboxEntriesProcessor
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def call(&block)
      config.outbox_entries_processor.call(&block)
    end
  end
end
