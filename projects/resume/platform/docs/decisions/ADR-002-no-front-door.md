# ADR-002 — Do not deploy Azure Front Door

**Status:** Accepted

## Decision
Do not place Azure Front Door in front of the portfolio.

## Rationale
Static Web Apps already globally distributes static assets. Front Door would add recurring cost and architectural complexity without a current WAF, routing, or multi-origin requirement.

## Revisit when
A concrete WAF, multi-origin, advanced routing, or enterprise edge-security requirement exists.
