# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::Configuration do
  describe "error_handler" do
    subject(:error_handler) { configuration.error_handler }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :error_handler }

      before do
        configuration.error_handler = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq RailsTransactionalOutbox::ErrorHandlers::NullErrorHandler }
    end
  end

  describe "database_connection_provider" do
    subject(:database_connection_provider) { configuration.database_connection_provider }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :database_connection_provider }

      before do
        configuration.database_connection_provider = :database_connection_provider
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be_nil }
    end
  end

  describe "logger" do
    subject(:logger) { configuration.logger }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :logger }

      before do
        configuration.logger = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be_nil }
    end
  end

  describe "transactional_outbox_worker_sleep_seconds" do
    subject(:transactional_outbox_worker_sleep_seconds) do
      configuration.transactional_outbox_worker_sleep_seconds
    end

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { 1.5 }

      before do
        configuration.transactional_outbox_worker_sleep_seconds = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq 0.5 }
    end
  end

  describe "transactional_outbox_worker_idle_delay_multiplier" do
    subject(:transactional_outbox_worker_idle_delay_multiplier) do
      configuration.transactional_outbox_worker_idle_delay_multiplier
    end

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { 1.5 }

      before do
        configuration.transactional_outbox_worker_idle_delay_multiplier = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq 10 }
    end
  end

  describe "outbox_model" do
    subject(:outbox_model) { configuration.outbox_model }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :outbox_model }

      before do
        configuration.outbox_model = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be_nil }
    end
  end

  describe "outbox_batch_size" do
    subject(:outbox_batch_size) { configuration.outbox_batch_size }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { 15 }

      before do
        configuration.outbox_batch_size = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq 100 }
    end
  end

  describe "transaction_provider" do
    subject(:transaction_provider) { configuration.transaction_provider }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :transaction_provider }

      before do
        configuration.transaction_provider = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be_nil }
    end
  end

  describe "#record_processors/#add_record_processor" do
    subject(:record_processors) { configuration.record_processors }

    let(:configuration) { described_class.new }

    context "when no custom record processors are added" do
      it "contains an single ActiveRecordProcessor" do
        expect(record_processors.size).to eq 1
        expect(record_processors.first).to be_a(RailsTransactionalOutbox::RecordProcessors::ActiveRecordProcessor)
      end
    end

    context "when a custom record processor is added" do
      let(:custom_processor) { :custom_processor }

      before do
        configuration.add_record_processor(custom_processor)
      end

      it "contains an ActiveRecordProcessor and the added one" do
        expect(record_processors.size).to eq 2
        expect(record_processors.first).to be_a(RailsTransactionalOutbox::RecordProcessors::ActiveRecordProcessor)
        expect(record_processors.last).to eq custom_processor
      end
    end
  end

  describe "outbox_entries_processor" do
    subject(:outbox_entries_processor) { configuration.outbox_entries_processor }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :outbox_entries_processor }

      before do
        configuration.outbox_entries_processor = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be_a RailsTransactionalOutbox::OutboxEntriesProcessors::NonOrderedProcessor }
    end
  end

  describe "raise_not_found_model_error" do
    subject(:raise_not_found_model_error) { configuration.raise_not_found_model_error }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { false }

      before do
        configuration.raise_not_found_model_error = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to be true }
    end
  end

  describe "lock_client" do
    subject(:lock_client) { configuration.lock_client }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :lock_client }

      before do
        configuration.lock_client = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq RailsTransactionalOutbox::NullLockClient }
    end
  end

  describe "lock_expiry_time" do
    subject(:lock_expiry_time) { configuration.lock_expiry_time }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_value) { :lock_expiry_time }

      before do
        configuration.lock_expiry_time = custom_value
      end

      it { is_expected.to eq custom_value }
    end

    context "when not set" do
      it { is_expected.to eq 10_000 }
    end
  end

  describe "outbox_entry_causality_key_resolver" do
    subject(:outbox_entry_causality_key_resolver) { configuration.outbox_entry_causality_key_resolver.call(model) }

    let(:configuration) { described_class.new }
    let(:model) { User }

    context "when set" do
      let(:custom_resolver) { ->(model) { model.to_s } }

      before do
        configuration.outbox_entry_causality_key_resolver = custom_resolver
      end

      it { is_expected.to eq "User" }
    end

    context "when not set" do
      it { is_expected.to be_nil }
    end
  end

  describe "#unprocessed_causality_keys_limit" do
    subject(:unprocessed_causality_keys_limit) { configuration.unprocessed_causality_keys_limit }

    let(:configuration) { described_class.new }

    context "when set" do
      let(:custom_unprocessed_causality_keys_limit) { "101" }

      before do
        configuration.unprocessed_causality_keys_limit = custom_unprocessed_causality_keys_limit
      end

      it { is_expected.to eq 101 }
    end

    context "when not set" do
      it { is_expected.to eq 10_000 }
    end
  end
end
