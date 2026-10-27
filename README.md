# Azure Solution Architect Portfolio

This repository contains my Azure Solution Architect portfolio and four architecture projects designed to demonstrate practical decision-making across reliability, security, privacy, hybrid cloud, Infrastructure as Code, GitOps, runtime resilience, and cost optimization.

## How to review the architecture

The Azure reference projects use a common review pattern so the reasoning is visible instead of buried in diagrams or Bicep:

**requirements → constraints → quality attributes → alternatives → decision → tradeoff → validation → known limitation / redesign trigger**

| Project | Requirements & constraints | NFR / evidence | Decision records | Known limitations |
|---|---|---|---|---|
| Cost-Optimized Portfolio Hosting | [`REQUIREMENTS-AND-CONSTRAINTS.md`](projects/resume/platform/REQUIREMENTS-AND-CONSTRAINTS.md) | [`nfr-matrix.md`](projects/resume/platform/docs/architecture/nfr-matrix.md) | [`docs/decisions/`](projects/resume/platform/docs/decisions/) | [`KNOWN-LIMITATIONS.md`](projects/resume/platform/KNOWN-LIMITATIONS.md) |
| Distributed E-Commerce Platform | [`REQUIREMENTS-AND-CONSTRAINTS.md`](projects/ecommerce/platform/REQUIREMENTS-AND-CONSTRAINTS.md) | [`nfr-matrix.md`](projects/ecommerce/platform/docs/architecture/nfr-matrix.md) | [`docs/decisions/`](projects/ecommerce/platform/docs/decisions/) | [`KNOWN-LIMITATIONS.md`](projects/ecommerce/platform/KNOWN-LIMITATIONS.md) |
| Privacy-Preserving AI Age Assurance | [`REQUIREMENTS-AND-CONSTRAINTS.md`](projects/age-verification/platform/REQUIREMENTS-AND-CONSTRAINTS.md) | [`nfr-matrix.md`](projects/age-verification/platform/docs/architecture/nfr-matrix.md) | [`docs/decisions/`](projects/age-verification/platform/docs/decisions/) | [`KNOWN-LIMITATIONS.md`](projects/age-verification/platform/KNOWN-LIMITATIONS.md) |
| Hybrid Kubernetes Chaos Lab | Physical lab + GitOps baseline | [`chaos/README.md`](projects/hybrid-kubernetes-chaos/chaos/README.md) and experiment reports | GitOps manifests + recorded experiment methodology | Single physical node; node-level HA not claimed |

For the portfolio-wide distinction between **design**, **compiler validation**, **live Azure control-plane validation**, and **runtime evidence**, see [`ARCHITECTURE-EVIDENCE.md`](ARCHITECTURE-EVIDENCE.md).

The public HTML case studies are intentionally shorter. The Markdown architecture packages and experiment records are the deeper evidence for reviewers who want to challenge the assumptions, alternatives, failure modes, quality attributes, measurements, and operating boundaries.

## Portfolio projects

### 1. Resume Portfolio / Static Hosting

A cost-optimized Azure Static Web Apps architecture for the portfolio itself. The baseline intentionally uses the Free plan and omits paid compute, Azure DNS, Front Door, databases, and a dedicated observability stack because the static workload does not require them.

Key themes:

- Azure Static Web Apps Free
- Managed HTTPS and browser security headers
- GitHub Actions CI/CD with secretless Azure OIDC
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

### 4. Hybrid Kubernetes Chaos Lab

A physical Kubernetes environment connected to Azure through Arc-enabled Kubernetes and reconciled through Flux GitOps. The lab runs kubeadm Kubernetes on Ubuntu Server with containerd and Calico and is used to produce repeatable runtime evidence rather than simply demonstrating a successful deployment.

Key themes:

- Physical Ubuntu Server / kubeadm Kubernetes cluster
- containerd with systemd cgroups
- Calico networking and NetworkPolicy
- Azure Arc-enabled Kubernetes and Cluster Connect
- Flux GitOps from this repository
- Three-replica `hybrid-demo` Service baseline
- In-cluster availability measurement
- Controlled pod deletion, CPU saturation, and network-isolation experiments
- Explicit single-node limitation before any node-level HA claim

Recorded runtime results include:

- **Pod failure:** 3/3 → 2/3 → 3/3 Ready in **6.89 seconds**, with **109/109 successful Service requests**.
- **CPU saturation:** one replica stressed for **30.73 seconds** at its **250m CPU limit**, remaining Running/Ready with zero restarts and **110/110 successful Service requests**.
- **Network isolation:** direct target-pod reachability observed as **reachable → unreachable → reachable** while the pod remained Ready; the Service completed **100/100 requests successfully** during the matched test window.

See `projects/hybrid-kubernetes-chaos/`.

## Resume

The downloadable `resume.pdf` is generated from the editable `resume-source.json` file by `tools/build_resume.py`. The current resume highlights selected Azure architecture work while preserving the professional experience and education sections.

`.github/workflows/resume-build.yml` rebuilds the PDF when the resume source or generator changes, verifies that the output remains exactly two pages, checks for expected content, and commits the generated PDF when it changes.

## Validation status

GitHub Actions authenticates to Azure through short-lived OpenID Connect federation rather than a stored Azure client secret. Evidence now spans both control-plane and runtime levels:

- **Static Portfolio:** deployed to Azure Static Web Apps Free and serving the live portfolio; Bicep/ARM validation and the production delivery path have been exercised.
- **E-Commerce:** dev, test, and production Bicep validation plus successful live Azure Resource Manager subscription-scope What-If for the dev architecture. Runtime application behavior is not claimed.
- **AI Age Assurance:** foundation/workload lint and build plus environment parameter validation; the dev foundation has passed live Azure Resource Manager What-If. End-to-end runtime privacy/model behavior is not claimed.
- **Hybrid Kubernetes:** physical Kubernetes cluster connected through Azure Arc, Flux GitOps reconciliation demonstrated, and three controlled chaos experiments measured at runtime.
- **Resume:** deterministic PDF build and two-page content verification.

The evidence boundary remains deliberate: What-If is not described as deployment, and the hybrid lab's successful pod/service experiments are not described as proof of node-level high availability. See [`ARCHITECTURE-EVIDENCE.md`](ARCHITECTURE-EVIDENCE.md) for the precise evidence levels.

## Repository structure

```text
.github/workflows/                       CI/CD and validation workflows
ARCHITECTURE-EVIDENCE.md                 Cross-project evidence register
projects/resume/                         Cost-optimized portfolio hosting case study
projects/ecommerce/                      Distributed e-commerce reference architecture
projects/age-verification/               Privacy-preserving AI age assurance architecture
projects/hybrid-kubernetes-chaos/        Azure Arc + Flux hybrid Kubernetes chaos lab
resume-source.json                       Editable resume content
tools/build_resume.py                    Deterministic resume PDF generator
resume.pdf                               Generated downloadable resume
index.html                               Portfolio homepage
styles.css                               Shared portfolio styling
portfolio-live-k8s.js                    Live Kubernetes portfolio/easter-egg updates
staticwebapp.config.json                 Static Web Apps routing/security configuration
```

## Design principle

The goal is not to maximize the number of Azure services used. Each project starts with workload requirements and documents why services are selected, what is deliberately omitted, what quality attributes the design is intended to satisfy, what evidence exists, and what future conditions would justify changing the architecture.
