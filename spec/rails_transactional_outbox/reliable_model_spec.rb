# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsTransactionalOutbox::ReliableModel do
  describe "creating outbox entries", :require_outbox_model, :freeze_time do
    let(:created_outbox_entry) { OutboxEntry.order(:created_at).last }

    describe "after create" do
      subject(:create_model) { User.create(name: "name") }

      let(:user) { create_model }
      let(:expected_changeset) do
        {
          "created_at" => [nil, Time.current.as_json],
          "updated_at" => [nil, Time.current.as_json],
          "id" => [nil, user.id],
          "name" => [nil, "name"]
        }
      end

      it "creates OutboxEntry" do
        expect do
          create_model
        end.to change { OutboxEntry.count }.from(0).to(1)
        expect(created_outbox_entry.resource_id).to eq user.id.to_s
        expect(created_outbox_entry.resource_class).to eq "User"
        expect(created_outbox_entry.changeset).to eq expected_changeset
        expect(created_outbox_entry.event_name).to eq "user_created"
      end
    end

    describe "after update" do
      subject(:update_model) { user.update!(name: "new name") }

      let!(:user) do
        User.create(name: "name", updated_at: 1.week.ago).tap { OutboxEntry.delete_all }
      end
      let(:expected_changeset) do
        {
          "updated_at" => [1.week.ago.as_json, Time.current.as_json],
          "name" => ["name", "new name"]
        }
      end

      it "creates OutboxEntry" do
        expect do
          update_model
        end.to change { OutboxEntry.count }.from(0).to(1)
        expect(created_outbox_entry.resource_id).to eq user.id.to_s
        expect(created_outbox_entry.resource_class).to eq "User"
        expect(created_outbox_entry.changeset).to eq expected_changeset
        expect(created_outbox_entry.event_name).to eq "user_updated"
      end
    end

    describe "after destroy" do
      subject(:destroy_model) { user.destroy! }

      let!(:user) { User.create(name: "name").tap { OutboxEntry.delete_all } }
      let(:expected_changeset) do
        {
          "created_at" => [nil, Time.current.as_json],
          "updated_at" => [nil, Time.current.as_json],
          "id" => [nil, user.id],
          "name" => [nil, "name"]
        }
      end

      it "creates OutboxEntry" do
        expect do
          destroy_model
        end.to change { OutboxEntry.count }.from(0).to(1)
        expect(created_outbox_entry.resource_id).to eq user.id.to_s
        expect(created_outbox_entry.resource_class).to eq "User"
        expect(created_outbox_entry.changeset).to eq expected_changeset
        expect(created_outbox_entry.event_name).to eq "user_destroyed"
      end
    end
  end

  describe ".reliable_after_commit_callbacks" do
    subject(:reliable_after_commit_callbacks) { User.reliable_after_commit_callbacks }

    it { is_expected.to be_a(RailsTransactionalOutbox::ReliableModel::ReliableCallbacksRegistry) }
  end

  describe ".reliable_after_commit" do
    subject(:reliable_after_commit_callbacks) { model_class.reliable_after_commit_callbacks }

    context "when block is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_commit if: -> { id == 1 } do
            self.name = "from block callback"
          end
        end
      end
      # ID is required for :if callback
      let(:user) { model_class.new(id: 1) }

      it "adds callback to registry that is properly callable" do
        expect(reliable_after_commit_callbacks.count).to eq 1

        expect(reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
        expect(reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
        expect(reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 1

        expect do
          reliable_after_commit_callbacks.first.call(user)
        end.to change { user.name }.from(nil).to("from block callback")
      end
    end

    context "when method name is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_commit :execute_callback, unless: -> { id != 1 }

          private

          def execute_callback
            self.name = "from execute callback"
          end
        end
      end
      # ID is required for :unless callback
      let(:user) { model_class.new(id: 1) }

      it "adds callback to registry that is properly callable" do
        expect(reliable_after_commit_callbacks.count).to eq 1

        expect(reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
        expect(reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
        expect(reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 1

        expect do
          reliable_after_commit_callbacks.first.call(user)
        end.to change { user.name }.from(nil).to("from execute callback")
      end
    end

    context "when neither block nor method name is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_commit if: -> { true }
        end
      end

      it { is_expected_block.to raise_error("You must provide a block or a method name") }
    end
  end

  describe ".reliable_after_create_commit" do
    context "when block is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_create_commit do
            self.name = "callback"
          end
        end
      end

      it "adds callback to registry" do
        expect(model_class.reliable_after_commit_callbacks.count).to eq 1

        expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 0
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
      end
    end

    context "when method name is provided" do
      context "when block is provided" do
        let(:model_class) do
          Class.new(ActiveRecord::Base) do
            self.table_name = "users"

            include RailsTransactionalOutbox::ReliableModel

            reliable_after_create_commit :execute_callback
          end
        end

        it "adds callback to registry" do
          expect(model_class.reliable_after_commit_callbacks.count).to eq 1

          expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 0
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
        end
      end
    end
  end

  describe ".reliable_after_update_commit" do
    context "when block is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_update_commit do
            self.name = "callback"
          end
        end
      end

      it "adds callback to registry" do
        expect(model_class.reliable_after_commit_callbacks.count).to eq 1

        expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 0
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
      end
    end

    context "when method name is provided" do
      context "when block is provided" do
        let(:model_class) do
          Class.new(ActiveRecord::Base) do
            self.table_name = "users"

            include RailsTransactionalOutbox::ReliableModel

            reliable_after_update_commit :execute_callback
          end
        end

        it "adds callback to registry" do
          expect(model_class.reliable_after_commit_callbacks.count).to eq 1

          expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 0
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
        end
      end
    end
  end

  describe ".reliable_after_destroy_commit" do
    context "when block is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_destroy_commit do
            self.name = "callback"
          end
        end
      end

      it "adds callback to registry" do
        expect(model_class.reliable_after_commit_callbacks.count).to eq 1

        expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 0
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 0
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 1
      end
    end

    context "when method name is provided" do
      context "when block is provided" do
        let(:model_class) do
          Class.new(ActiveRecord::Base) do
            self.table_name = "users"

            include RailsTransactionalOutbox::ReliableModel

            reliable_after_destroy_commit :execute_callback
          end
        end

        it "adds callback to registry" do
          expect(model_class.reliable_after_commit_callbacks.count).to eq 1

          expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 0
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 0
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 1
        end
      end
    end
  end

  describe ".reliable_after_save_commit" do
    context "when block is provided" do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "users"

          include RailsTransactionalOutbox::ReliableModel

          reliable_after_save_commit do
            self.name = "callback"
          end
        end
      end

      it "adds callback to registry" do
        expect(model_class.reliable_after_commit_callbacks.count).to eq 1

        expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
        expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
      end
    end

    context "when method name is provided" do
      context "when block is provided" do
        let(:model_class) do
          Class.new(ActiveRecord::Base) do
            self.table_name = "users"

            include RailsTransactionalOutbox::ReliableModel

            reliable_after_save_commit :execute_callback
          end
        end

        it "adds callback to registry" do
          expect(model_class.reliable_after_commit_callbacks.count).to eq 1

          expect(model_class.reliable_after_commit_callbacks.for_event_type(:create).count).to eq 1
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:update).count).to eq 1
          expect(model_class.reliable_after_commit_callbacks.for_event_type(:destroy).count).to eq 0
        end
      end
    end
  end

  describe "previous_changes", :require_outbox_model, freeze_time: "2022-08-29 12:00:00" do
    subject(:previous_changes) { user.previous_changes }

    let(:user) { User.create(name: "current name") }

    context "when without overrides" do
      let(:expected_changeset) do
        {
          "name" => [nil, "current name"],
          "created_at" => [nil, Time.current],
          "updated_at" => [nil, Time.current],
          "id" => [nil, user.id]
        }
      end

      it { is_expected.to eq(expected_changeset) }
    end

    context "when with overrides" do
      before do
        user.previous_changes = { "name" => [nil, "current name"] }
      end

      let(:expected_changeset) do
        {
          "name" => [nil, "current name"]
        }
      end

      it { is_expected.to eq(expected_changeset) }
    end
  end

  describe "#original_previous_changes", :require_outbox_model, freeze_time: "2022-08-29 12:00:00" do
    subject(:original_previous_changes) { user.original_previous_changes }

    let(:user) { User.create(name: "current name") }
    let(:expected_changeset) do
      {
        "name" => [nil, "current name"],
        "created_at" => [nil, Time.current],
        "updated_at" => [nil, Time.current],
        "id" => [nil, user.id]
      }
    end

    it { is_expected.to eq(expected_changeset) }
  end

  describe "#reliable_after_commit_callbacks" do
    subject(:reliable_after_commit_callbacks) { User.new.reliable_after_commit_callbacks }

    it { is_expected.to be_a(RailsTransactionalOutbox::ReliableModel::ReliableCallbacksRegistry) }
  end
end
