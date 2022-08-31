# frozen_string_literal: true

class RailsTransactionalOutbox
  class Railtie < Rails::Railtie
    railtie_name :rails_transactional_outbox

    rake_tasks do
      load "tasks/rails_transactional_outbox.rake"
    end
  end
end
