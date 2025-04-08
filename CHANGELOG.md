## [Unreleased]

## [1.1.0] - 2025-04-08

- Make gem compatible with Datadog gem 2.0

## [1.0.0] - 2024-08-28

- [Feature] add latency tracking ability via Datadog
- [Breaking Change] Require Ruby >= 3.1

## [0.4.0] - 2024-01-25

- add config option to specify causality keys limit

## [0.3.1] - 2023-05-24

- add config option whether to raise error when outbox entry record is not found

## [0.3.0] - 2022-12-20

- Move to file-based healthchecks, instead of using Redis-based ones.

## [0.2.1] - 2022-09-08

- Simplify update to 0.2 (`causality_key` is not required if `outbox_entry_causality_key_resolver` is not used)

## [0.2.0] - 2022-09-08

- Introduce `RailsTransactionalOutbox::OutboxEntriesProcessors::OrderedByCausalityKeyProcessor`

## [0.1.0] - 2022-08-23

- Initial release
