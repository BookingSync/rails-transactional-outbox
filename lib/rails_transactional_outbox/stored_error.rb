# frozen_string_literal: true

class RailsTransactionalOutbox
  class StoredError < StandardError
    attr_reader :error_class, :error_message

    def initialize(error_class:, error_message:)
      @error_class = error_class
      @error_message = error_message
      super("#{error_class}: #{error_message}")
    end
  end
end
