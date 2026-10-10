# Security Policy and Architecture Notes

## Reporting

Do not include real credentials, customer data, payment card data, or production secrets in issues, logs, test fixtures, or screenshots.

## Secret handling

- Use managed identities for Azure service authentication.
- Use Key Vault for application secrets that cannot be replaced by workload identity.
- Do not commit connection strings containing keys, client secrets, payment secrets, or certificates.
- GitHub Actions should use OIDC/federated Azure authentication.

## Payment boundary

This reference architecture does not store cardholder data. A payment worker should use a payment-provider sandbox/tokenization API and persist only provider transaction identifiers, non-sensitive status, amounts, timestamps, and idempotency metadata needed by the order workflow.

## Production hardening checklist

- WAF in Prevention mode after tuning.
- Data-service public network access disabled.
- Private endpoints and private DNS verified from each region.
- App Service direct public origin path restricted to the specific Front Door instance.
- SCM/Kudu hardened; use a private/self-hosted runner if public SCM access is unacceptable.
- Least-privilege RBAC reviewed per workload identity.
- Dependency/code scanning enabled.
- Diagnostic settings/alerts configured for security-relevant resources.
- Customer/admin authorization tests pass.
