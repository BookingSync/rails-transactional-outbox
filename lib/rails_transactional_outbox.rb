# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/rails-transactional-outbox.rb")
loader.setup

class RailsTransactionalOutbox
end
