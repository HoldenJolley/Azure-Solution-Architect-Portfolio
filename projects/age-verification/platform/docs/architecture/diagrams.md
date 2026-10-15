# Architecture diagrams

## Production request flow

```mermaid
flowchart LR
    U[User browser] -->|Capture in memory| C[Resize / re-encode / strip metadata]
    C -->|AES-256-GCM encrypt| E[Encrypted image envelope]
    E -->|TLS 1.2+| FD[Azure Front Door Premium + WAF]
    FD -->|Private Link| GW[Gateway Container App]
    GW -->|Ciphertext only / internal mTLS| INF[Inference Container App]
    INF -->|Managed Identity| KV[Azure Key Vault Premium]
    KV -->|RSA-OAEP-256 unwrap| INF
    INF -->|Decrypt in process memory| M[Customer AI model]
    M --> P[Policy: approve / deny / indeterminate]
    P -->|Sign decision attestation| KV
    P --> R[Binary result + short-lived signed token]
```

## Trust boundaries

```mermaid
flowchart TB
    subgraph Device[User-controlled device]
        B[Browser / capture]
        CR[Client cryptography]
    end

    subgraph Edge[Microsoft edge]
        FD[Front Door Premium + WAF]
    end

    subgraph PrivateAzure[Customer private Azure boundary]
        GW[Gateway - ciphertext only]
        INF[Inference service - plaintext only in memory]
        REDIS[Azure Managed Redis - opaque nonce/session state]
        KV[Key Vault Premium - HSM-backed keys]
        ACR[Private Azure Container Registry]
        MON[App Insights / Log Analytics - metadata only]
    end

    B --> CR --> FD --> GW --> INF
    GW --> REDIS
    INF --> KV
    GW --> KV
    ACR --> GW
    ACR --> INF
    GW --> MON
    INF --> MON
```

## Cryptographic sequence

```mermaid
sequenceDiagram
    participant Browser
    participant Gateway
    participant Inference
    participant KeyVault as Key Vault
    participant Model as Customer model

    Browser->>Gateway: GET /v1/crypto/public-key
    Gateway-->>Browser: Public key + key id
    Browser->>Gateway: POST /v1/session
    Gateway-->>Browser: sessionId + nonce + expiry
    Note over Browser: Re-encode frame; generate AES-256-GCM key and IV
    Note over Browser: Encrypt image and wrap AES key with RSA-OAEP-256
    Browser->>Gateway: POST /v1/verify (ciphertext envelope)
    Gateway->>Gateway: Validate TTL, nonce, schema, rate policy
    Gateway->>Inference: Forward ciphertext envelope
    Inference->>KeyVault: Unwrap AES key using managed identity
    KeyVault-->>Inference: Unwrapped AES key
    Note over Inference: Decrypt image only in process memory
    Inference->>Model: In-memory pixels/tensor
    Model-->>Inference: Transient age estimate/quality
    Note over Inference: Convert to APPROVED / DENIED / INDETERMINATE and discard plaintext, tensors, raw age, AES key
    Inference->>KeyVault: Sign short-lived attestation
    KeyVault-->>Inference: Signature
    Inference-->>Gateway: Decision + signed attestation
    Gateway-->>Browser: approved boolean + attestation; Cache-Control: no-store
```

## Deployment topology

```mermaid
flowchart TB
    Internet((Internet)) --> FD[Azure Front Door Premium / WAF]
    FD -->|Private Link| ACAENV[Internal Azure Container Apps environment]

    subgraph VNet[Production VNet]
      ACAENV --> GW[Gateway Container App]
      GW --> INF[Inference Container App]
      PE[Private Endpoint subnet]
    end

    PE --> KV[Key Vault Premium]
    PE --> ACR[Azure Container Registry Premium]
    PE --> REDIS[Azure Managed Redis]

    INF --> KV
    GW --> REDIS
    ACR --> GW
    ACR --> INF
    ACAENV --> MON[Log Analytics / Application Insights]
```

## Data handling invariant

```mermaid
flowchart LR
    A[Raw camera frame] --> B[Browser memory]
    B --> C[Encrypted envelope]
    C --> D[Network buffers]
    D --> E[Inference process memory]
    E --> F[Customer model memory]
    F --> G[Decision]

    X[(Blob / DB / queue / disk)]:::blocked
    B -. prohibited .-> X
    C -. prohibited .-> X
    E -. prohibited .-> X
    F -. prohibited .-> X

    classDef blocked stroke-dasharray: 5 5;
```

The prohibited paths are architectural requirements, not suggestions. Application code and observability configuration must be tested continuously to ensure request bodies and image-derived artifacts never enter durable storage.

## Failure-mode view

```mermaid
flowchart TB
    GFAIL[Gateway replica fails] --> ACA1[Container Apps]
    ACA1 -->|route to healthy replica| GOK[Healthy gateway replica]

    IFAIL[Inference replica fails] --> ACA2[Internal Container Apps routing]
    ACA2 -->|new request / retry reaches healthy replica| IOK[Healthy inference replica]

    KVFAIL[Key Vault unavailable] --> KVCLOSED[Fail closed\nno verification]
    RFAIL[Managed Redis unavailable] --> RCLOSED[Fail closed for new one-time sessions]
    MFAIL[Customer model unhealthy] --> READY[/ready fails]
    READY --> UNAVAILABLE[Verification denied / unavailable]

    REGION[Regional failure] --> BASELINE[Current baseline unavailable]
    BASELINE --> EXTENSION[Recovery requires approved second regional stamp\nwith coordinated key/session/model semantics]
```

The fail-closed branches are security requirements. A dependency outage must not silently turn into an approval path.

## Multi-region extension dependencies

```mermaid
flowchart LR
    STAMP1[Regional stamp A] --> FD[Front Door origin group]
    STAMP2[Regional stamp B] --> FD

    STAMP1 --> K1[Regional key strategy]
    STAMP2 --> K2[Regional key strategy]
    STAMP1 --> S1[Session / nonce strategy]
    STAMP2 --> S2[Session / nonce strategy]
    STAMP1 --> M1[Approved model version]
    STAMP2 --> M2[Approved model version]

    K1 -. must remain deterministic/trusted .-> K2
    S1 -. one-time semantics must remain consistent .-> S2
    M1 -. approved version must match policy .-> M2
```

A second region is not just another Container Apps environment. Key versioning, one-time session semantics, model version, routing, and attestation trust all have to remain deterministic before regional failover can be considered credible.
