# Retry policy (BayRelay KB sample)

- **Transient network errors**: exponential backoff, max 5 attempts at Lambda; Step Functions retries per state definition.
- **Checksum failures**: do not auto-retry; require operator confirmation before any retry.
- **Policy denials**: no retry; update routing policy or partner configuration.

This document is embedded for Bedrock Knowledge Base ingestion tests and demos.
