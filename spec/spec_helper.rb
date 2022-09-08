# frozen_string_literal: true

require "bundler/setup"
require "support/is_expected_block"
require "ddtrace"
require "timecop"
require "active_record"
require "crypt_keeper"
require "sentry-ruby"
require "redlock"
require "rails-transactional-outbox"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all) do
    ENV["REDIS_URL"] ||= "redis://localhost:6379/1"
    Time.zone = "UTC"
  end

  config.before(:example, :require_outbox_model) do
    RailsTransactionalOutbox.configure do |conf|
      conf.outbox_model = OutboxEntry
    end
  end

  config.around(:example, :freeze_time) do |example|
    freeze_time = example.metadata[:freeze_time]
    time_now = freeze_time == true ? Time.current.round : freeze_time
    Timecop.freeze(time_now) { example.run }
  end

  config.after do
    RailsTransactionalOutbox.reset
    OutboxEntry.delete_all
    User.delete_all
  end

  include IsExpectedBlock

  database_name = ENV.fetch("DATABASE_NAME", "rails-transactional-outbox-test")
  database_url = ENV.fetch("DATABASE_URL", "postgres://:@localhost/#{database_name}")
  postgres_url = ENV.fetch("POSTGRES_URL", "postgres://:@localhost")
  ActiveRecord::Base.establish_connection(database_url)
  begin
    database = ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    ActiveRecord::Base.establish_connection(postgres_url).connection.create_database(database_name)
    ActiveRecord::Base.establish_connection(database_url)
    database = ActiveRecord::Base.connection
  end
  database.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

  database.drop_table(:outbox_entries) if database.table_exists?(:outbox_entries)
  database.create_table(:outbox_entries) do |t|
    t.string "resource_class"
    t.string "resource_id"
    t.string "event_name", null: false
    t.string "context", null: false
    t.datetime "processed_at"
    t.jsonb "arguments", null: false, default: {}
    t.jsonb "changeset", null: false, default: {}
    t.string "causality_key"
    t.datetime "failed_at"
    t.datetime "retry_at"
    t.string "error_class"
    t.string "error_message"
    t.integer "attempts", null: false, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false

    t.index %w[resource_class event_name], name: "idx_outbox_on_resource_class_and_event"
    t.index %w[resource_class resource_id], name: "idx_outbox_on_resource_class_and_resource_id"
    t.index ["context"], name: "idx_outbox_on_topic"
    t.index ["created_at"], name: "idx_outbox_on_created_at"
    t.index ["created_at"], name: "idx_outbox_on_created_at_not_processed", where: "processed_at IS NULL"
    t.index %w[resource_class created_at], name: "idx_outbox_on_resource_class_and_created_at"
    t.index %w[resource_class processed_at], name: "idx_outbox_on_resource_class_and_processed_at"
  end

  database.drop_table(:outbox_with_encryption_entries) if database.table_exists?(:outbox_with_encryption_entries)
  database.create_table(:outbox_with_encryption_entries) do |t|
    t.string "resource_class"
    t.string "resource_id"
    t.string "event_name", null: false
    t.string "context", null: false
    t.datetime "processed_at"
    t.text "arguments", null: false, default: "{}"
    t.text "changeset", null: false, default: "{}"
    t.string "causality_key"
    t.datetime "failed_at"
    t.datetime "retry_at"
    t.string "error_class"
    t.string "error_message"
    t.integer "attempts", null: false, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false

    t.index %w[resource_class event_name], name: "idx_outbox_enc_entries_on_resource_class_and_event"
    t.index %w[resource_class resource_id], name: "idx_outbox_enc_entries_on_resource_class_and_resource_id"
    t.index ["context"], name: "idx_outbox_enc_entries_on_topic"
    t.index ["created_at"], name: "idx_outbox_enc_entries_on_created_at"
    t.index ["created_at"], name: "idx_outbox_enc_entries_on_created_at_not_processed", where: "processed_at IS NULL"
    t.index %w[resource_class created_at], name: "idx_outbox_enc_entries_on_resource_class_and_created_at"
    t.index %w[resource_class processed_at], name: "idx_outbox_enc_entries_on_resource_class_and_processed_at"
  end

  database.drop_table(:users) if database.table_exists?(:users)
  database.create_table(:users) do |t|
    t.string "name", null: false
    t.string "sentinel"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  class OutboxEntry < ActiveRecord::Base
    include RailsTransactionalOutbox::OutboxModel
  end

  class OutboxWithEncryptionEntry < ActiveRecord::Base
    include RailsTransactionalOutbox::OutboxModel

    crypt_keeper :changeset, :arguments, encryptor: :postgres_pgp, key: "secret_key", encoding: "UTF-8"

    outbox_encrypt_json_for :changeset, :arguments
  end

  class User < ActiveRecord::Base
    include RailsTransactionalOutbox::ReliableModel

    reliable_after_commit do
      self.sentinel ||= ""
      self.sentinel += "after_commit_sentinel"
    end

    reliable_after_commit :ack_sentinel, on: :update

    private

    def ack_sentinel
      self.sentinel ||= ""
      self.sentinel += "ack_sentinel"
    end
  end

  RSpec::Matchers.define_negated_matcher :avoid_changing, :change
end
