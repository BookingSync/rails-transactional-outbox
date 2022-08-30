# frozen_string_literal: true

class RailsTransactionalOutbox
  class RecordProcessor
    attr_reader :config
    private     :config

    def initialize(config: RailsTransactionalOutbox.configuration)
      @config = config
    end

    def call(record)
      applicable_record_processors = record_processors.select { |processor| processor.applies?(record) }
      applicable_record_processors.any? or raise ProcessorNotFoundError.new(record)

      applicable_record_processors.each { |processor| processor.call(record) }
    end

    delegate :record_processors, to: :config

    class ProcessorNotFoundError < StandardError
      attr_reader :record
      private     :record

      def initialize(record)
        super()
        @record = record
      end

      def to_s
        "no processor was found for record with ID: #{record.id}, context: #{record.context}"
      end
    end
  end
end
