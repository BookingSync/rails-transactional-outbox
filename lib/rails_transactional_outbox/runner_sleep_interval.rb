# frozen_string_literal: true

class RailsTransactionalOutbox
  class RunnerSleepInterval
    # TODO: maybe apply some backoff or longer pause if there were no entries to be processed?
    def self.interval_for(processed_entries, sleep_seconds, idle_delay_multiplier)
      if processed_entries.any?
        sleep_seconds
      else
        sleep_seconds * idle_delay_multiplier
      end
    end
  end
end
