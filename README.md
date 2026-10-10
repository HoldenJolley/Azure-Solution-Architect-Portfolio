# Azure Solution Architect Portfolio

Personal portfolio for Holden Jolley showcasing Azure architecture, cloud infrastructure, security, automation, and deployable reference projects.

## Portfolio projects

- **Resume Portfolio** — the portfolio/resume experience itself, including the downloadable resume.
- **E-Commerce Platform** — a production-oriented Azure reference architecture with modular Bicep, CI/CD, security, observability, reliability, and architecture documentation.
- **AI Age Assurance Platform** — a production-oriented privacy and security landing zone for bring-your-own AI age models, with client-side encryption, private inference, no image retention, HSM-backed keys, anti-replay state, and signed binary attestations.

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
│       ├── index.html
│       └── platform/
│           ├── infra/
│           ├── contracts/
│           ├── docs/
│           ├── scripts/
│           └── src/
└── .github/workflows/
```

## E-Commerce infrastructure

The e-commerce project contains a deployable Infrastructure-as-Code foundation under [`projects/ecommerce/platform`](projects/ecommerce/platform/README.md). It includes:

- Azure Front Door and WAF
- Regional App Service API and worker tiers
- Azure Cosmos DB
- Azure Service Bus
- Azure Key Vault
- Azure Data Lake Storage Gen2
- Application Insights and Log Analytics
- Regional VNets, private endpoints, and private DNS
- Managed identities and RBAC
- Dev, test, and production parameter sets
- Architecture Decision Records (ADRs)
- Security, disaster recovery, testing, operations, and cost documentation

## Local portfolio preview

Open `index.html` in a browser or serve the repository with any static web server.

## E-Commerce validation

From the repository root:

```powershell
./projects/ecommerce/platform/scripts/validate.ps1 -Environment dev -RunWhatIf
```

See [`projects/ecommerce/platform/README.md`](projects/ecommerce/platform/README.md) for prerequisites, deployment steps, and current limitations.

## AI Age Assurance infrastructure

The age-assurance project under [`projects/age-verification/platform`](projects/age-verification/platform/README.md) is a privacy-preserving Azure landing zone for customer-supplied AI models. It uses client-side envelope encryption, Front Door Premium + WAF, Private Link, private Azure Container Apps, Key Vault HSM-backed keys, Azure Managed Redis anti-replay state, ACR, managed identities, and strict no-image-retention contracts.

Validation:

```powershell
./projects/age-verification/platform/scripts/validate.ps1 -Environment dev
```
