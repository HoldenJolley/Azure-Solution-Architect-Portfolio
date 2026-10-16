# Architecture Diagrams

These Mermaid diagrams are source-controlled so GitHub can render them directly. Export PNG/SVG versions later for the portfolio site.

## Solution overview

```mermaid
flowchart TB
    User[Customer / Client] --> AFD[Azure Front Door + WAF]
    AFD --> API1[App Service API - Primary]
    AFD --> API2[App Service API - Secondary]
    API1 --> Cosmos[(Cosmos DB)]
    API2 --> Cosmos
    API1 --> SB[Service Bus Topic]
    API2 --> SB
    SB --> Inv[Inventory Worker]
    SB --> Pay[Payment Worker]
    SB --> Ship[Shipping Worker]
    SB --> Analytics[Analytics Worker]
    Inv --> Cosmos
    Pay --> Cosmos
    Ship --> Cosmos
    Analytics --> Lake[(Data Lake Gen2)]
    API1 --> AI[Application Insights]
    API2 --> AI
    AI --> LAW[(Log Analytics)]
```

## Checkout and inventory reservation

```mermaid
sequenceDiagram
    actor C as Customer
    participant API as Commerce API
    participant DB as Cosmos DB
    participant SB as Service Bus
    participant I as Inventory Worker
    participant P as Payment Worker
    C->>API: POST /api/checkout
    API->>DB: Atomically reserve inventory
    alt Inventory available
        DB-->>API: Reservation created
        API->>DB: Create Pending order
        API->>SB: Publish OrderCreated
        API-->>C: 202 / order id
        SB->>P: OrderCreated
        P->>SB: PaymentCompleted or PaymentFailed
        SB->>I: Payment result
        alt Payment completed
            I->>DB: Commit reservation
        else Payment failed
            I->>DB: Release reservation
        end
    else Out of stock
        DB-->>API: Conditional conflict / unavailable
        API-->>C: Out of stock
    end
```

## Regional network path

```mermaid
flowchart LR
    Internet --> AFD[Azure Front Door]
    AFD --> API[App Service API\nFront Door-only restriction]
    API --> Integration[App Service VNet Integration]
    Integration --> VNet[Regional VNet]
    VNet --> PE[Private Endpoint Subnet]
    PE --> Cosmos[(Cosmos DB)]
    PE --> SB[Service Bus]
    PE --> KV[Key Vault]
    PE --> Lake[Data Lake]
    DNS[Private DNS Zones] --> VNet
```

## Event flow

```mermaid
flowchart LR
    API[Commerce API] -->|OrderCreated| Topic[commerce-events topic]
    Topic --> IS[inventory subscription]
    Topic --> PS[payment subscription]
    Topic --> SS[shipping subscription]
    Topic --> AS[analytics subscription]
    IS --> IW[Inventory Worker]
    PS --> PW[Payment Worker]
    SS --> SW[Shipping Worker]
    AS --> AW[Analytics Worker]
    AW --> Bronze[(Data Lake bronze)]
```

## Failure-mode view

```mermaid
flowchart TB
    F1[Primary API origin unhealthy] --> AFD[Azure Front Door]
    AFD -->|route to healthy origin| API2[Secondary App Service API]

    F2[Cosmos write region unavailable] --> COSMOS[Cosmos DB]
    COSMOS -->|automatic failover| CSECONDARY[Configured secondary write region]

    F3[Service Bus regional outage] --> SB[Single Service Bus namespace]
    SB -->|current baseline| PAUSE[Async order processing can pause]
    PAUSE --> BACKLOG[Requires explicit messaging-continuity enhancement]

    F4[Payment provider unavailable] --> RETRY[Retry / backoff]
    RETRY --> ORDER[Order remains non-complete]
    ORDER --> RELEASE[Reserved inventory eventually released]

    F5[Analytics unavailable] --> COMMERCE[Commerce path continues]
    COMMERCE --> CATCHUP[Analytics catches up later]
```

This diagram intentionally shows that “two application regions” does **not** make every dependency multi-region. The current messaging namespace remains a separate continuity risk.

## Worker redelivery and dead-letter behavior

```mermaid
flowchart LR
    MSG[Service Bus message] --> WORKER[Worker receives message]
    WORKER --> EFFECT[Attempt idempotent business effect]
    EFFECT -->|success| COMPLETE[Complete message]
    EFFECT -->|process crashes / transient failure| REDELIVER[Lock expires / retry]
    REDELIVER --> WORKER
    EFFECT -->|repeated poison failure| DLQ[Dead-letter queue]
    DLQ --> RUNBOOK[Operator runbook / diagnosis]
```

The application implementation must make business side effects idempotent; the infrastructure alone cannot guarantee that redelivery is harmless.
