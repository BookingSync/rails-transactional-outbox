## [Unreleased]

- Move to file-based healthchecks, instead of using Redis-based ones.

## [0.2.1] - 2022-09-08

- Simplify update to 0.2 (`causality_key` is not required if `outbox_entry_causality_key_resolver` is not used)

## [0.2.0] - 2022-09-08

- Introduce `RailsTransactionalOutbox::OutboxEntriesProcessors::OrderedByCausalityKeyProcessor`

## [0.1.0] - 2022-08-23

- Initial release
