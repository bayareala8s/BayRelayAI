# Retry policy (sample KB document)

- **Transient network errors**: exponential backoff, max 5 attempts at Lambda, Step Functions retry with interval per state.
- **Checksum failures**: do not auto-retry; require operator confirmation.
- **Policy denials**: no retry; update routing policy or partner configuration.

This file is illustrative content for the `bayrelay-kb-source-*` bucket. Curate production content and restrict IAM; guardrails do not filter retrieved chunks at runtime.
