# ADR-004: Bring-your-own-model contract

**Decision:** The landing zone does not standardize on one age-estimation model. Customers supply an inference container implementing the model/privacy contract.

**Rationale:** Model choice, license, fairness, threshold, and regulatory suitability are product-specific.

**Consequence:** Production readiness includes model governance outside Bicep.
