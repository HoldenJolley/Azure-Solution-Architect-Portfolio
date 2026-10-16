# Operations and Recovery

## Normal validation flow

1. Commit portfolio changes and open a pull request.
2. GitHub Actions lints/builds the Bicep and production parameters.
3. GitHub authenticates to Azure through OIDC and runs Resource Manager What-If.
4. If the production Static Web App already exists, the workflow publishes a temporary pull-request preview; before the initial deployment, this step safely skips.
5. Review the code, What-If result, and rendered preview when available.
6. Merge approved changes to `main`; the push runs validation/What-If again but does not create resources by itself.

## Production deployment

Production is deliberately manual rather than merge-driven:

1. confirm the `main` validation/What-If result;
2. run the `static portfolio` workflow from `main` with `deploy=true`;
3. the workflow authenticates through OIDC;
4. Bicep creates or updates the resource group and Free-tier Static Web App;
5. the workflow retrieves and masks the deployment token at runtime;
6. the curated public artifact is published.

This gate prevents a merge from unexpectedly creating Azure resources.

## Rollback

Because the application is static and source-controlled, content rollback is a Git operation:

1. revert the problematic commit;
2. push/merge the revert;
3. explicitly run the production deployment workflow when the rollback is ready to publish.

No database rollback, schema migration, or state recovery is required.

## Failure scenarios

| Failure | Response |
|---|---|
| Bad content release | Revert Git commit and manually republish from `main` |
| GitHub Actions failure | Inspect workflow and rerun after correction |
| Azure What-If failure | Stop; resolve the control-plane, policy, quota, or template issue before deployment |
| Deployment token exposure | Reset the Static Web Apps deployment token and rerun deployment |
| Custom-domain issue | Verify DNS records and SWA custom-domain binding |
| Azure Static Web Apps outage | Accept Free-tier service limitation; reassess if an SLA becomes required |

## Backup

GitHub is the source of truth. No separate backup of deployed web content is necessary because the site can be reconstructed from source control.
