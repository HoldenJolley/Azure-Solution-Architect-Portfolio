# Compliance and Legal Notes

This repository is a technical reference, not legal advice.

Age-assurance requirements differ by jurisdiction and product category. Before production use, engage privacy/legal stakeholders to determine applicable requirements for minors, biometric processing, automated decision-making, retention, consent/notice, accessibility, appeals/fallback methods, and data residency.

The architecture intentionally minimizes data by avoiding identity matching and image retention, but a face image and inferred age can still be sensitive personal data. Do not assume that “not stored” means “unregulated.”

Maintain a documented product policy covering:

- why age assurance is necessary and proportionate;
- legal basis/notice/consent where applicable;
- model accuracy and fairness;
- uncertainty/fail-closed behavior;
- alternative verification path;
- retention and telemetry;
- processor/subprocessor responsibilities;
- incident response;
- periodic re-evaluation.
