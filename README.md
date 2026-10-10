# Azure Solution Architect Portfolio

Personal portfolio for Holden Jolley showcasing Azure architecture, cloud infrastructure, security, automation, and deployable reference projects.

## Portfolio projects

- **Resume Portfolio / Static Hosting** — the portfolio itself, hosted on Azure Static Web Apps Free as a cost-optimization reference architecture with Bicep, GitHub OIDC, security headers, preview deployments, and a documented $0/month Azure hosting target within quota.
- **E-Commerce Platform** — a production-oriented Azure reference architecture with modular Bicep, CI/CD, security, observability, reliability, and architecture documentation.
- **AI Age Assurance Platform** — a production-oriented privacy and security landing zone for bring-your-own AI age models, with client-side encryption, private inference, no image retention, HSM-backed keys, anti-replay state, and signed binary attestations.

## Repository structure

```text
.
├── index.html
├── styles.css
├── script.js
├── resume.pdf
├── staticwebapp.config.json
├── projects/
│   ├── resume/
│   │   ├── index.html
│   │   └── platform/
│   ├── ecommerce/
│   │   ├── index.html
│   │   └── platform/
│   └── age-verification/
│       ├── index.html
│       └── platform/
└── .github/workflows/
```

## Resume Portfolio / Static Hosting

The portfolio hosting project under [`projects/resume/platform`](projects/resume/platform/README.md) demonstrates cost-first architecture. The baseline contains one Azure Resource Group and one Azure Static Web Apps resource on the Free SKU. The design intentionally avoids paid compute, Azure DNS, Front Door, databases, Functions, and a dedicated observability stack until requirements justify them.

Validation:

```powershell
./projects/resume/platform/scripts/validate.ps1 -RunWhatIf
```

## E-Commerce infrastructure

The e-commerce project contains a deployable Infrastructure-as-Code foundation under [`projects/ecommerce/platform`](projects/ecommerce/platform/README.md), including Front Door/WAF, App Service, Cosmos DB, Service Bus, Key Vault, Data Lake, monitoring, private networking, managed identities, CI/CD, and architecture documentation.

Validation:

```powershell
./projects/ecommerce/platform/scripts/validate.ps1 -Environment dev -RunWhatIf
```

## AI Age Assurance infrastructure

The age-assurance project under [`projects/age-verification/platform`](projects/age-verification/platform/README.md) is a privacy-preserving Azure landing zone for customer-supplied AI models. It uses client-side envelope encryption, Front Door Premium + WAF, Private Link, private Azure Container Apps, Key Vault HSM-backed keys, Azure Managed Redis anti-replay state, ACR, managed identities, and strict no-image-retention contracts.

Validation:

```powershell
./projects/age-verification/platform/scripts/validate.ps1 -Environment dev
```

## Local portfolio preview

Open `index.html` in a browser or serve the repository with any static web server.
