# Operations and Recovery

## Normal deployment

1. Commit portfolio changes.
2. Open a pull request.
3. Static Web Apps creates/updates a preview deployment after Azure OIDC is configured.
4. Review the rendered site.
5. Merge to `main`.
6. GitHub Actions deploys production.

## Rollback

Because the application is static and source-controlled, rollback is a Git operation:

1. revert the problematic commit;
2. push/merge the revert;
3. allow the deployment workflow to republish the previous content.

No database rollback, schema migration, or state recovery is required.

## Failure scenarios

| Failure | Response |
|---|---|
| Bad content release | Revert Git commit and redeploy |
| GitHub Actions failure | Inspect workflow, rerun after correction |
| Deployment token exposure | Reset Static Web Apps deployment token |
| Custom-domain issue | Verify DNS records and SWA custom-domain binding |
| Azure Static Web Apps outage | Accept Free-tier service limitation; reassess if SLA becomes required |

## Backup

GitHub is the source of truth. No separate backup of deployed web content is necessary because the site can be reconstructed from source control.
