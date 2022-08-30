# frozen_string_literal: true

class RailsTransactionalOutbox
  class ExponentialBackoff
    def self.backoff_for(multiplier, count)
      (multiplier * (2**count))
    end
  end
end
