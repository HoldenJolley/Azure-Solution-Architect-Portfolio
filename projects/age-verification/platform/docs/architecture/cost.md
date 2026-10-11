# Cost Architecture

Primary cost drivers:

- Front Door Premium/WAF;
- dedicated Container Apps workload profile and minimum replicas;
- optional confidential-compute DC profile;
- Azure Managed Redis;
- ACR Premium (required for private endpoint);
- Key Vault Premium/HSM operations;
- Log Analytics ingestion/retention;
- private endpoints.

## Cost-aware profiles

Development can lower replica counts and WAF to Detection mode. It should not weaken the core privacy controls (client-side encryption, private Key Vault/ACR/Redis, no image storage).

For a portfolio/demo subscription, consider deploying only when testing and tearing down afterward. Production should size CPU/memory and Redis from measured concurrency and model latency rather than guesses.
