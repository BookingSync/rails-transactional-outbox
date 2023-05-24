# RailsTransactionalOutbox

An implementation of transactional outbox pattern to be used with Rails.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-transactional-outbox'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rails-transactional-outbox

## Usage

To get familiar with the pattern:
- [Pattern: Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html)
- [Transactional Outbox: What is it and why you need it?](https://morningcoffee.io/what-is-a-transaction-outbox-and-why-you-need-it.html)

Create the initializer with the following content:

``` rb
Rails.application.config.to_prepare do
  RailsTransactionalOutbox.configure do |config|
    config.database_connection_provider = ActiveRecord::Base # required
    config.transaction_provider = ActiveRecord::Base # required
    config.logger = Rails.logger # required
    config.outbox_model = OutboxEntry # required
    config.error_handler = Sentry # non-required, but highly recommended, defaults to RailsTransactionalOutbox::ErrorHandlers::NullErrorHandler. When using Sentry, you will probably want to exclude SignalException `config.excluded_exceptions += ["SignalException"]`.

    config.transactional_outbox_worker_sleep_seconds = 1 # optional, defaults to 0.5
    config.transactional_outbox_worker_idle_delay_multiplier = 5 # optional, defaults to 1, if there are no outbox entries to be processed, then the sleep time for the thread will be equal to transactional_outbox_worker_idle_delay_multiplier * transactional_outbox_worker_sleep_seconds
    config.outbox_batch_size = 100 # optional, defaults to 100
    config.add_record_processor(MyCustomOperationProcerssor) # optional, by default it contains only one processor for ActiveRecord, but you could add more
    config.raise_not_found_model_error = true # optional, defaults to true. Should the error be raised if outbox entry model is not found

    config.lock_client = Redlock::Client.new([ENV["REDIS_URL"]]) # required if you want to use RailsTransactionalOutbox::OutboxEntriesProcessors::OrderedByCausalityKeyProcessor, defaults to RailsTransactionalOutbox::NullLockClient. Check its interface and the interface of `redlock` gem. To cut the long story short, when the lock is acquired, a hash with the structure outlined in RailsTransactionalOutbox::NullLockClient should be yielded, if the lock is not acquired, a nil should be yielded.
    config.lock_expiry_time  = 10_000 # not required, defaults to 10_000, the unit is milliseconds
    config.outbox_entries_processor = `RailsTransactionalOutbox::OutboxEntriesProcessors::OrderedByCausalityKeyProcessor`.new # not required, defaults to RailsTransactionalOutbox::OutboxEntriesProcessors::NonOrderedProcessor.new
    config.outbox_entry_causality_key_resolver = ->(model) { model.tenant_id } # not required, defaults to a lambda returning nil. Needed when using `outbox_entry_causality_key_resolver`
  end
end
```

Create OutboxEntry model (or use a different name, just make sure to adjust config/migration) with the following content:

``` rb
class OutboxEntry < ApplicationRecord
  include RailsTransactionalOutbox::OutboxModel

  # optional, if you want to use encryption
  crypt_keeper :changeset, :arguments, encryptor: :postgres_pgp, key: ENV.fetch("CRYPT_KEEPER_KEY"), encoding: "UTF-8"
  outbox_encrypt_json_for :changeset, :arguments
end
```

And use the following migration:

``` rb
create_table(:outbox_entries) do |t|
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
  t.index ["causality_key", created_at"], name: "idx_outbox_enc_entries_on_c_key_crtd_at_n_proc", where: "processed_at IS NULL"
  t.index %w[resource_class created_at], name: "idx_outbox_enc_entries_on_resource_class_and_created_at"
  t.index %w[resource_class processed_at], name: "idx_outbox_enc_entries_on_resource_class_and_processed_at"
end
```

Keep in mind that `arguments` and `changeset` are `text` columns here. If you don't want to use encryption, replace them with `jsonb` columns:

```rb
t.jsonb "arguments", null: false, default: {}
t.jsonb "changeset", null: false, default: {}
```

The following columns: `resource_class`, `resource_id` and `changeset` are dedicated to ActiveRecord integration. Do not try to modify these columns for custom processors.

As the last step, include `RailsTransactionalOutbox::ReliableModel` module in the models that are supposed to have reliable `after_commit` callbacks, for example:

``` ruby
class User < ActiveRecord::Base
  include RailsTransactionalOutbox::ReliableModel
end
```

Now, you can just replace `after_commit` callbacks with `reliable_after_commit`. The interface is going to be the same as for `after_commit`:

- you can provide `:on` option to specific when the callback should be executed
- you can use both blocks or symbols as the method names
- you can pass `:if` and `:unless` options
- you can also use `reliable_after_create_commit`, `reliable_after_update_commit`, `reliable_after_destroy_commit`, `reliable_after_save_commit`.

When executing the callbacks, you can use `previous_changes` which will contain the changes that are persisted as changesets. One potential gotcha is that Time/Date types are stored as strings, so oyu might need to handle some conversion to be on the safe side.

Inclusion of this module will result in OutboxEntry records being created after create/update/destroy. For these entries, the `context` column will be populated with `active_record` value.

### Ordering/Preserving causality

There are two type of processors that have very different behavior depending on the concurrency:

1. `RailsTransactionalOutbox::OutboxEntriesProcessors::NonOrderedProcessor` (used by default):

By default, the order will be preserved only if there is no concurrency (i.e. a single process with a single thread). Internally, `.lock("FOR UPDATE SKIP LOCKED")` is used to avoid conflicts and other issues related to concurrency but at the cost of no longer preserving the causality of outbox entries (although the entries are ordered by `created_at`).

2`RailsTransactionalOutbox::OutboxEntriesProcessors::OrderedByCausalityKeyProcessor`:

Uses lock (e.g. Redlock) to preserve causality determined by `causality_key` (e.g. a tenant ID).


### Custom processors

If you want to add some custom processor either for ActiveRecord or for custom service objects, create an object inheriting from `RailsTransactionalOutbox::RecordProcessors::BaseProcessor`, which has the following interface:


``` ruby
class RailsTransactionalOutbox
  class RecordProcessors
    class BaseProcessor
      def applies?(_record)
        raise "implement me"
      end

      def call(_record)
        raise "implement me"
      end
    end
  end
end
```

For a reference, this is an example of `ActiveRecordProcessor`:

``` ruby
class RailsTransactionalOutbox
  class RecordProcessors
    class ActiveRecordProcessor < RailsTransactionalOutbox::RecordProcessors::BaseProcessor
      ACTIVE_RECORD_CONTEXT = "active_record"
      private_constant :ACTIVE_RECORD_CONTEXT

      def self.context
        ACTIVE_RECORD_CONTEXT
      end

      def applies?(record)
        record.context == ACTIVE_RECORD_CONTEXT
      end

      def call(record)
        model = record.infer_model or raise CouldNotFindModelError.new(record)
        model.previous_changes = record.transformed_changeset.with_indifferent_access
        model.reliable_after_commit_callbacks.for_event_type(record.event_type).each do |callback|
          callback.call(model)
        end
      end

      class CouldNotFindModelError < StandardError
        attr_reader :record

        def initialize(record)
          super()
          @record = record
        end

        def to_s
          "could not find model for outbox record: #{record.id}"
        end
      end
    end
  end
end
```

If you want to extent the behavior of `ActiveRecordProcessor`, you could actually create a new processor that handles exactly the same context as multiple processors can be used for the same context.

When adding a custom processor for service objects/operations, you might want to use `arguments` column, to keep all the arguments there.

If you use encryption and you want to deal with properly deserialized hash, you `transformed_changeset` and `transformed_arguments` methods (like `ActiveRecordProcessor` does.)

When dealing with custom service objects, remember to create OutboxEntry records inside the same transaction:

``` rb
class MyServiceObject
  def call(user_id)
    transaction do
      execute_some_logic
      OutboxEntry.create!(context: "service_object", event_name: "my_service_object_called", arguments: { user_id: user_id })
    end
  end
end
```

### Running outbox worker

Use the following Rake task:

```
RAILS_TRANSACTIONAL_OUTBOX_THREADS_NUMBER=5 DB_POOL=10 bundle exec rake rails_transactional_outbox:worker
```

If you want to use just a single thread:

```
bundle exec rake bookingsync_prometheus:producer
```

### Archiving old outbox records

You will probably want to periodically archive/delete processed outbox records. It's recommended to use [tartarus-rb](https://github.com/BookingSync/tartarus-rb) for that.

Here is an example config:

```
tartarus.register do |item|
  item.model = OutboxEntry
  item.cron = "5 4 * * *"
  item.queue = "default"
  item.archive_items_older_than = -> { 3.days.ago }
  item.timestamp_field = :processed_at
  item.archive_with = :delete_all_using_limit_in_batches
end
```

### Health Checks


Then, Uou need to explicitly enable the health check (e.g. in the initializer):

``` rb
RailsTransactionalOutbox.enable_outbox_worker_healthcheck
```

To perform the actual health check, use `bin/rails_transactional_outbox_health_check`. On success, the script exits with `0` status and on failure, it logs the error and exits with `1` status.

```
bundle exec rails_transactional_outbox_health_check
```

It works for both readiness and liveness checks.

#### Events, hooks and monitors

You can subscribe to certain events that are published by `RailsTransactionalOutbox.monitor`. The monitor is based on [`dry-monitor`](https://github.com/dry-rb/dry-monitor).

Available events and arguments are:

- "rails_transactional_outbox.started", no arguments
- "rails_transactional_outbox.stopped", no arguments
- "rails_transactional_outbox.shutting_down", no arguments
- "rails_transactional_outbox.record_processing_failed", arguments: outbox_record
- "rails_transactional_outbox.record_processed", no arguments: outbox_record
- "rails_transactional_outbox.error", arguments: error, error_message
- "rails_transactional_outbox.heartbeat", no arguments


#### Testing the logic from reliable_after_commit callbacks

The fastest way to handle it would be to add this to `rails_helper.rb`:

``` ruby
ApplicationRecord.after_commit do
  RailsTransactionalOutbox::OutboxEntriesProcessor.new.call
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/BookingSync/rails-transactional-outbox.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
