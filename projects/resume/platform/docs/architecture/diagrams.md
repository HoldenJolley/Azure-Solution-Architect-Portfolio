# Architecture Diagrams

These Mermaid diagrams are source-controlled so GitHub can render them directly. They describe the intended production topology and delivery/security paths without implying that the Azure Static Web App has already been deployed.

## Public request path

```mermaid
flowchart LR
    U[Visitor browser] -->|HTTPS| D[External DNS\ncurrently GoDaddy]
    D --> SWA[Azure Static Web Apps Free]
    SWA --> C[Static portfolio content\nHTML + CSS + JavaScript + resume PDF]

    SWA -. managed certificate after domain setup .-> TLS[Managed TLS]
```

`holdenjolley.com` remains registered externally. The hosting architecture does not require moving DNS into Azure; the external DNS provider can map the domain to Static Web Apps when the site is deployed.

## Secretless infrastructure delivery path

```mermaid
flowchart LR
    GH[GitHub repository] --> GA[GitHub Actions]
    GA -->|OIDC token request| OIDC[GitHub OIDC provider]
    OIDC -->|federated identity| ENTRA[Microsoft Entra ID]
    ENTRA -->|short-lived Azure token| GA
    GA -->|ARM What-If / deployment| ARM[Azure Resource Manager]
    ARM --> RG[Resource group]
    RG --> SWA[Static Web Apps Free]
```

No reusable Azure client secret is required for GitHub-to-Azure authentication.

## Content publication path

```mermaid
flowchart TB
    SRC[Repository content] --> CI[GitHub Actions]
    CI --> VALIDATE[Validate Bicep + JavaScript + public-site metadata]
    VALIDATE --> DIST[Assemble curated dist/ artifact]
    DIST --> TOKEN[Retrieve Static Web Apps deployment token at runtime]
    TOKEN -->|masked token| PUBLISH[Publish static content]
    PUBLISH --> SWA[Azure Static Web Apps]

    INTERNAL[Internal IaC / ADR / workflow docs] -. intentionally excluded .-> DIST
```

The deployment token is retrieved at runtime and masked rather than stored as a permanent GitHub deployment secret. Only the curated public artifact is published.

## Production change-control path

```mermaid
flowchart LR
    CHANGE[Code change] --> PR[Pull request]
    PR --> BUILD[Bicep lint/build + site validation]
    BUILD --> WHATIF[Live Azure ARM What-If]
    WHATIF --> REVIEW[Human review]
    REVIEW --> MAIN[main branch]
    MAIN --> MANUAL[Manual workflow_dispatch\ndeploy=true]
    MANUAL --> DEPLOY[Infrastructure + content deployment]
```

A merge or push by itself does not create production Azure resources. Production creation remains explicitly manually gated.

## Recovery path

```mermaid
flowchart LR
    ISSUE[Bad deployment / content regression] --> GIT[Identify known-good Git commit]
    GIT --> REVERT[Revert or redeploy known-good source]
    REVERT --> ACTIONS[GitHub Actions]
    ACTIONS --> SWA[Static Web Apps]
    SWA --> VERIFY[Verify public site]
```

Because the site is stateless and source-controlled, the baseline recovery mechanism is **revert + redeploy**, not database or VM backup restoration.

## Deliberately omitted services

```mermaid
flowchart TB
    REQ[Static public portfolio requirements] --> BASELINE[Static Web Apps Free]

    BASELINE --> INCLUDED[HTTPS\nGlobal static delivery\nCustom domain support\nPR previews]

    AFD[Azure Front Door] -. no current requirement .-> BASELINE
    DNS[Azure DNS] -. external DNS already exists .-> BASELINE
    APP[App Service / Functions] -. no server runtime needed .-> BASELINE
    DB[Database / Storage account] -. no mutable application state .-> BASELINE
    OBS[App Insights / Log Analytics] -. no backend transaction graph .-> BASELINE
```

The omission of these services is an architecture decision, not an implementation gap. Each should be reconsidered only when a new requirement justifies the additional cost or operational surface.