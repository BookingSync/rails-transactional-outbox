# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Integration scenario" do
  describe "handling outbox entries", :freeze_time do
    let(:outbox_record) do
      OutboxEntry.find_by(resource_class: resource.class.model_name.to_s, resource_id: resource.id)
    end
    let(:create_resource) { User.create!(name: "name") }
    let(:resource) { create_resource }

    let(:call_outbox_worker) do
      Thread.new do
        create_resource
        RailsTransactionalOutbox.start_outbox_worker(threads_number: 1)
        sleep 1.0
        Process.kill("TERM", 0)
      end
    end

    before do
      RailsTransactionalOutbox.configure do |config|
        config.database_connection_provider = ActiveRecord::Base
        config.transaction_provider = ActiveRecord::Base
        config.logger = Logger.new($stdout)
        config.outbox_model = OutboxEntry
        config.error_handler = Sentry
      end
    end

    it "processes things using outbox worker" do
      expect do
        call_outbox_worker
        sleep 1.0
      end.to change { outbox_record.reload.processed_at }.from(nil).to(Time.current)
    end
  end
end
