# frozen_string_literal: true

class RailsTransactionalOutbox
  class ErrorHandlers
    class NullErrorHandler
      def self.capture_exception(_error); end
    end
  end
end
