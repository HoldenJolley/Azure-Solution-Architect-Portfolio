# ADR-002: No image persistence

**Decision:** Provision no datastore or queue for verification images and prohibit application logging/storage of plaintext or ciphertext images.

**Rationale:** The safest retained image is no image.

**Consequence:** Retraining/debugging cannot depend on production selfies; use synthetic/consented test datasets outside this runtime.
