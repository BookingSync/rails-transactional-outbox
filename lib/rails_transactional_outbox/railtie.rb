# frozen_string_literal: true

class RailsTransactionalOutbox
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/rails_transactional_outbox.rake"
    end
  end
end
