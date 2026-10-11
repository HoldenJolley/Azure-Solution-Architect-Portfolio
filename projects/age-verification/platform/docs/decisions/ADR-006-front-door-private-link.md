# ADR-006: Front Door Premium private origin

**Decision:** Use Front Door Premium + WAF and Private Link directly to the private Container Apps environment.

**Rationale:** Keeps the origin off the public Internet while retaining global edge/WAF/rate-limiting controls.

**Consequence:** Private endpoint connection approval is an explicit deployment step.
