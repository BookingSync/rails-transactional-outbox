# frozen_string_literal: true

class RailsTransactionalOutbox
  class RecordProcessors
    class BaseProcessor
      def applies?(_record)
        raise "implement me"
      end

      def call(_record)
        raise "implement me"
      end
    end
  end
end
