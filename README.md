# Azure Solution Architect Portfolio

Personal portfolio for Holden Jolley showcasing Azure architecture, cloud infrastructure, security, automation, and deployable reference projects.

## Portfolio projects

- **Resume Portfolio** — the portfolio/resume experience itself, including the downloadable resume.
- **E-Commerce Platform** — a production-oriented Azure reference architecture with modular Bicep, CI/CD, security, observability, reliability, and architecture documentation.
- **Age Verification Platform** — a security and identity-focused project placeholder for the next reference implementation.

## Repository structure

```text
.
├── index.html
├── styles.css
├── script.js
├── resume.pdf
├── projects/
│   ├── resume/
│   ├── ecommerce/
│   │   ├── index.html
│   │   └── platform/
│   │       ├── infra/
│   │       ├── scripts/
│   │       ├── docs/
│   │       └── src/
│   └── age-verification/
└── .github/workflows/
```

## E-Commerce infrastructure

The e-commerce project contains a deployable Infrastructure-as-Code foundation under [`projects/ecommerce/platform`](projects/ecommerce/platform/README.md). It includes Azure Front Door and WAF, regional App Service API and worker tiers, Azure Cosmos DB, Azure Service Bus, Azure Key Vault, Data Lake Storage Gen2, Application Insights and Log Analytics, regional networking, managed identities and RBAC, environment parameter sets, ADRs, and operations/security/recovery documentation.

## Local portfolio preview

Open `index.html` in a browser or serve the repository with any static web server.

## E-Commerce validation

From the repository root:

```powershell
./projects/ecommerce/platform/scripts/validate.ps1 -Environment dev -RunWhatIf
```

See [`projects/ecommerce/platform/README.md`](projects/ecommerce/platform/README.md) for prerequisites, deployment steps, and current limitations.
