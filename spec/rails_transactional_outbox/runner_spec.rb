# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::Runner, :freeze_time do
  describe "start/stop" do
    subject(:start) { runner.start }

    let(:runner) { described_class.new }
    let(:database_connection_provider) { double(connection: double(reconnect!: true)) }
    let(:transaction_provider) do
      Class.new do
        def transaction
          yield
        end
      end.new
    end
    let(:logger) do
      Class.new do
        def initialize
          @info = []
          @debug = []
          @error = []
        end

        def info(message)
          @info << message
        end

        def debug(message)
          @debug << message
        end

        def error(message)
          @error << message
        end
      end.new
    end
    let(:error_handler) do
      Class.new do
        attr_reader :errors

        def initialize
          @errors = []
        end

        def capture_exception(error)
          errors << error
        end
      end.new
    end

    let!(:outbox_record_1) { OutboxEntry.create(event_name: event_name, context: "", created_at: Time.current) }
    let!(:outbox_record_2) { OutboxEntry.create(event_name: event_name, context: "", created_at: 1.week.ago) }
    let(:event_name) { "example_resource_created" }
    let(:test_record_processor) do
      Class.new(RailsTransactionalOutbox::RecordProcessors::BaseProcessor) do
        def applies?(_record)
          true
        end

        def call(record)
          record.update!(context: "updated_from_processor")
        end
      end.new
    end
    let(:monitor) { RailsTransactionalOutbox.monitor }

    before do
      RailsTransactionalOutbox.configure do |config|
        config.database_connection_provider = database_connection_provider
        config.transaction_provider = transaction_provider
        config.outbox_model = OutboxEntry
        config.error_handler = error_handler
        config.add_record_processor(test_record_processor)
        config.logger = logger
      end

      OutboxEntry.where.not(id: [outbox_record_1, outbox_record_2]).destroy_all
      allow(database_connection_provider.connection).to receive(:reconnect!)
      allow(monitor).to receive(:instrument).and_call_original
    end

    context "when error happens" do
      let(:error) { StandardError.new("error") }

      context "when the error is caused by something different than a publishing error" do
        before do
          allow(database_connection_provider).to receive(:connection).and_raise(error)
        end

        it "raises and reports error" do
          expect do
            start
          end.to raise_error(error)

          expect(error_handler.errors).to eq([error])
          expect(monitor).to have_received(:instrument).with("rails_transactional_outbox.error",
            error: error, error_message: error.message)
        end
      end

      context "when the error is caused by something when processing entry" do
        before do
          allow(test_record_processor).to receive(:call).and_call_original
          allow(test_record_processor).to receive(:call).with(outbox_record_2).and_raise(error)
          Thread.new { start }
          sleep 0.5
        end

        after do
          runner.stop
        end

        it "does not raise the error but it reports the error" do
          expect(error_handler.errors).to eq([error])
          expect(monitor).to have_received(:instrument).with("rails_transactional_outbox.record_processing_failed",
            outbox_record: instance_of(OutboxEntry)).at_least(:once)
        end
      end
    end

    context "when no error happens" do
      before do
        allow(RailsTransactionalOutbox::RunnerSleepInterval).to receive(:interval_for).and_call_original
        Thread.new { start }
        sleep 0.5
      end

      after do
        runner.stop
      end

      it "ensures that the database connection is established" do
        expect(database_connection_provider.connection).to have_received(:reconnect!)
      end

      it "processed the record via the processor" do
        expect(outbox_record_1.reload.processed_at).to eq Time.current
        expect(outbox_record_1.context).to eq "updated_from_processor"
        expect(outbox_record_2.reload.processed_at).to eq Time.current
        expect(outbox_record_2.context).to eq "updated_from_processor"
      end

      it "handles instrumentation" do
        expect(monitor).to have_received(:instrument).with("rails_transactional_outbox.started")
        expect(monitor).to have_received(:instrument).with("rails_transactional_outbox.heartbeat").at_least(:once)
        expect(monitor).to have_received(:instrument).with("rails_transactional_outbox.record_processed",
          outbox_record: instance_of(OutboxEntry)).exactly(2)
      end

      it "sleeps for a specific amount of time after processing determined
      by RailsTransactionalOutbox::RunnerSleepInterval" do
        expect(RailsTransactionalOutbox::RunnerSleepInterval).to have_received(:interval_for)
      end
    end
  end
end
