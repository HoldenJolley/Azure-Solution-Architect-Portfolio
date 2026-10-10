# Azure Solution Architect Portfolio

This repository contains my Azure Solution Architect portfolio and three architecture projects designed to demonstrate practical decision-making across reliability, security, privacy, Infrastructure as Code, and cost optimization.

## Portfolio projects

### 1. Resume Portfolio / Static Hosting

A cost-optimized Azure Static Web Apps architecture for the portfolio itself. The baseline intentionally uses the Free plan and omits paid compute, Azure DNS, Front Door, databases, and a dedicated observability stack because the static workload does not require them.

Key themes:

- Azure Static Web Apps Free
- Managed HTTPS and browser security headers
- GitHub Actions CI/CD with Azure OIDC readiness
- Bicep-based infrastructure
- Source-control-driven recovery
- Explicit Free-tier quota and upgrade triggers

See `projects/resume/`.

### 2. E-Commerce Platform

A production-oriented Azure reference architecture for a distributed commerce backend.

Key themes:

- Azure Front Door + WAF
- Regional App Service API and workers
- Cosmos DB and Service Bus
- Key Vault and Data Lake Storage
- Application Insights and Log Analytics
- VNets, private endpoints, and private DNS
- Managed identities and RBAC
- Multi-region and disaster-recovery design
- Modular Bicep with dev, test, and production parameter profiles

See `projects/ecommerce/`.

### 3. AI Age Assurance Platform

A privacy-preserving Azure landing zone for bring-your-own age-estimation models.

Key themes:

- Client-side AES-256-GCM + RSA-OAEP envelope encryption
- Azure Front Door Premium + WAF + Private Link
- Private Azure Container Apps inference
- Key Vault Premium with HSM-backed keys
- Azure Managed Redis anti-replay state
- Private Azure Container Registry
- Managed identities and RBAC
- No intentional verification-image storage
- Signed binary approval/denial attestation
- Optional confidential compute

See `projects/age-verification/`.

## Resume

The downloadable `resume.pdf` is generated from the editable `resume-source.json` file by `tools/build_resume.py`. The resume includes a **Selected Azure Architecture Projects** section covering all three portfolio projects while preserving the professional experience and education sections.

`.github/workflows/resume-build.yml` rebuilds the PDF when the resume source or generator changes, verifies that the output remains exactly two pages, checks for the expected project and education content, and commits the generated PDF when it changes.

## Validation status

The current project templates have passed their GitHub Actions compiler-level gates:

- E-Commerce: dev, test, and production Bicep validation
- AI Age Assurance: foundation/workload lint and build plus all environment parameter files
- Static Portfolio: Bicep lint, build, and production parameter build
- Resume: deterministic PDF build and two-page content verification

Azure Resource Manager `what-if` remains the next cloud-side validation gate once GitHub-to-Azure OIDC is configured. These projects do not claim to have been deployed to Azure yet.

## Repository structure

```text
.github/workflows/        CI/CD and validation workflows
projects/resume/          Cost-optimized portfolio hosting case study
projects/ecommerce/       Distributed e-commerce reference architecture
projects/age-verification/ Privacy-preserving AI age assurance architecture
resume-source.json        Editable resume content
tools/build_resume.py     Deterministic resume PDF generator
resume.pdf                Generated downloadable resume
index.html                Portfolio homepage
styles.css                Shared portfolio styling
staticwebapp.config.json  Static Web Apps routing/security configuration
```

## Design principle

The goal is not to maximize the number of Azure services used. Each project starts with workload requirements and documents why services are selected, what is deliberately omitted, and what future conditions would justify changing the architecture.
