# Known Limitations and Production Decisions

- The landing zone does not include an AI model. Customers supply gateway/inference images that implement the documented contracts.
- AI age estimation is statistical and is not equivalent to government-issued identity verification.
- Liveness detection is not implemented by infrastructure; integrate it in the customer workload if required.
- The landing zone cannot technically stop malicious customer application code from writing plaintext images to its own process filesystem or external destinations. The supplied contracts, egress design, code review, container controls, and tests are required to maintain the privacy invariant.
- Azure Container Apps confidential compute is optional because region support is limited. Standard production profiles use dedicated workload profiles; high-assurance deployments can switch to a supported DC-series profile.
- Front Door-to-Container Apps Private Link requires approval of the private endpoint connection after deployment.
- Azure Managed Redis stores only short-lived session/replay records. Persistence is disabled at the application contract level and keys are TTL-bound; operators must not repurpose it for user/image data.
- The default topology is single-region for the stateful inference plane. Multi-region active-active verification requires key, session, routing, and model-version consistency decisions documented in the DR guide.
- Customer-specific legal, privacy, accessibility, bias/fairness, and model-governance reviews are outside the scope of Bicep.
