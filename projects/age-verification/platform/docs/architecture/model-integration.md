# Model Integration

The platform treats the model as a replaceable customer workload.

## Deployment boundary

- Customer builds/publishes the inference image to the provisioned ACR.
- Image implements `contracts/model-contract.md`.
- Bicep deploys the image to a private inference Container App.
- Gateway image is separately versioned and public-facing only through Front Door.

## Recommended release process

1. Train/evaluate model outside production.
2. Produce model card and fairness/threshold report.
3. Build immutable inference container.
4. Scan/sign container and record digest.
5. Deploy to test.
6. Run privacy, security, load, and threshold tests.
7. Require production approval.
8. Deploy exact digest to production.
9. Monitor aggregate quality/latency without retaining source images.
10. Preserve previous approved image for rollback.
