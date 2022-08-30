# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::ReliableModel::ReliableCallback do
  describe "#for_event?" do
    context "when the event type is included in the on option" do
      subject(:for_event?) { reliable_callback.for_event?(event_type) }

      let(:reliable_callback) { described_class.new(double, options) }
      let(:event_type) { :create }
      let(:options) { { on: [:create] } }

      it { is_expected.to be true }
    end

    context "when the event type is not included in the on option" do
      subject(:for_event?) { reliable_callback.for_event?(event_type) }

      let(:reliable_callback) { described_class.new(double, options) }
      let(:event_type) { :create }
      let(:options) { { on: [:update] } }

      it { is_expected.to be false }
    end
  end

  describe "#call" do
    subject(:call) { reliable_callback.call(example_record) }

    let(:reliable_callback) { described_class.new(callback, options) }
    let(:callback) do
      -> { self.name = "set_from_callback" }
    end
    let(:options) { {} }
    let(:example_record) { User.new }

    context "when there is a extra condition defined" do
      context "when :if option is added" do
        let(:options) { { if: test_proc } }
        let(:test_proc) { -> { id == 123 } }

        context "when the condition is true" do
          before do
            example_record.id = 123
          end

          it "executes the callback" do
            expect do
              call
            end.to change { example_record.name }.from(nil).to("set_from_callback")
          end
        end

        context "when the condition is false" do
          it "does not executes the callback" do
            expect do
              call
            end.not_to change { example_record.name }
          end
        end
      end

      context "when :unless option is added" do
        let(:options) { { unless: test_proc } }
        let(:test_proc) { -> { id == 123 } }

        context "when the condition is true" do
          before do
            example_record.id = 123
          end

          it "does not executes the callback" do
            expect do
              call
            end.not_to change { example_record.name }
          end
        end

        context "when the condition is false" do
          it "executes the callback" do
            expect do
              call
            end.to change { example_record.name }.from(nil).to("set_from_callback")
          end
        end
      end
    end

    context "when there is not extra condition defined" do
      it "executes the callback" do
        expect do
          call
        end.to change { example_record.name }.from(nil).to("set_from_callback")
      end
    end
  end
end
