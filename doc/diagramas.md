# Diagramas — Conversión de FitRoom a SaaS multi-tenant

Referencias: [ADRs](./adr/) · [Stories](./stories/)

## 1. Componentes (vista general)

```mermaid
flowchart TB
    subgraph WEB["gym-web (Angular 16 + Material)"]
        direction TB
        subgraph WSA["Módulo superadmin (solo SUPERADMIN)"]
            VISTA_C["Vista Centros<br/>(CRUD + Entrar al centro)"]
            VISTA_U["Vista Usuarios<br/>(todos los centros)"]
            VISTA_A["Auditoría<br/>(audit_log)"]
        end
        subgraph WC["Módulo centro (ADMIN / CENTER_ADMIN / USER / REGISTRATION)"]
            VSOC["Socios · Tarifas · Cortesías"]
            VTUR["Turnos · Check-In · Ventas · Inventario · Reportes"]
            VCFG["Configuración del centro<br/>(gym_profile / gym_config)"]
        end
        BANNER["Banner modo superadmin<br/>(visible solo impersonado)"]
        AUTHS["auth.service.ts<br/>(token + userRole en localStorage)"]
        GUARD["AuthGuard + rutas por rol"]
    end

    subgraph API["gym-api (Spring Boot 3.2.5)"]
        direction TB
        AC["AuthController<br/>/api/v1/auth/signin · signup"]
        TP["TokenProvider<br/>(claims: username, user_role,<br/>center_uuid, impersonated_by)"]
        FILTER["Filtro JWT / SecurityFilterChain<br/>(extrae centro del token,<br/>valida centro activo)"]
        SAPI["API superadmin<br/>/api/v1/centers · impersonate · exit-impersonation"]
        SVC["Servicios de operación con scoping<br/>(Member, WorkShift, CheckIn, GymConfig,<br/>rates, sales, inventory, reports)"]
        AUD["AuditService"]
        JOB["Scheduler jobs<br/>(procesan todos los centros activos)"]
    end

    subgraph DB["MySQL 8.0 (esquema compartido)"]
        direction TB
        CENTERS[("centers<br/>(id + center_uuid)")]
        USERS[("users<br/>(center_id nullable)")]
        OPER[("Tablas operativas<br/>(center_id): members, work_shifts,<br/>subscriptions, check_in, sales…")]
        CFG[("gym_profile / gym_config<br/>(center_id)")]
        AUDIT[("audit_log")]
        CAT[("Catálogos globales:<br/>states, cities, colonias")]
        SEED[("Socios semilla por centro:<br/>Público en General · Visita")]
    end

    WSA --> GUARD
    WC --> GUARD
    GUARD --> AUTHS
    AUTHS -- "Bearer JWT" --> FILTER
    FILTER --> AC
    FILTER --> SAPI
    FILTER --> SVC
    SVC --> JOB
    SAPI --> AUD
    SVC --> AUD
    AUD --> AUDIT
    FILTER --> TP
    AC --> TP
    SAPI --> CENTERS
    SAPI --> USERS
    SVC --> USERS
    SVC --> OPER
    SVC --> CFG
    SVC --> SEED
    SVC --> CAT
    AUD --> AUDIT
    BANNER -. "solo si hay claim impersonated_by" .-> WSA
```

## 2. Flujo: login y claim de centro en el JWT

```mermaid
sequenceDiagram
    participant UI as gym-web (fit-login)
    participant AC as AuthController
    participant TP as TokenProvider
    participant F as Filtro JWT
    participant S as Servicios (scoping)

    UI->>AC: POST /api/v1/auth/signin (username, password)
    AC->>TP: genera token
    TP-->>AC: JWT con claims { username, user_role, center_uuid? }
    AC-->>UI: { accessToken, username, userRole, centerUuid, centerName }
    UI->>UI: localStorage (token, userRole) · timer logout 4h

    Note over UI,S: Cada request posterior
    UI->>F: Authorization: Bearer JWT (sin enviar el centro)
    F->>F: valida firma, user_role, centro activo
    F->>S: request con contexto { centerId, role }
    S->>S: WHERE center_id = :centerId
    S-->>UI: datos solo del centro
```

El superadmin entra al login igual, pero su token **no lleva** `center_uuid`; solo
puede llamar a la API de superadmin (ST-006) o impersonar (ST-009).

## 3. Flujo: impersonación de centro

```mermaid
sequenceDiagram
    participant SA as Superadmin (gym-web)
    participant API as gym-api
    participant AUD as AuditService → audit_log
    participant C as Operación del centro

    SA->>API: POST /api/v1/centers/{uuid}/impersonate
    API->>API: centro activo? actor = SUPERADMIN?
    API->>AUD: IMPERSONATION_START (actor, centro)
    API-->>SA: JWT nuevo { center_uuid, user_role: CENTER_ADMIN, impersonated_by: sa }
    SA->>SA: guarda token · muestra banner "Modo superadmin — [Centro]"
    SA->>C: opera como CENTER_ADMIN (check-in, socios, turnos…)
    SA->>API: POST /api/v1/auth/exit-impersonation
    API->>AUD: IMPERSONATION_END
    API-->>SA: JWT del superadmin (sin centro)
    SA->>SA: banner desaparece · vuelve al módulo superadmin
```

Bloqueos mientras impersonado: crear/editar `CENTER_ADMIN`/`SUPERADMIN`, ver
auditoría, impersonar de nuevo.

## 4. Flujo: apertura/cierre de turno fuera de horario

```mermaid
flowchart TB
    A["Responsable abre/cierra turno<br/>(WorkShiftService)"] --> B{"¿Dentro de<br/>OPERATING_HOURS + desfase?"}
    B -- "Sí" --> OK["Turno abierto/cerrado normal<br/>(reviewer ADMIN si aplica)"]
    B -- "No (fuera de horario o desfase > threshold)" --> P["Estado OPEN_PENDING_APPROVAL /<br/>CLOSED_PENDING_APPROVAL"]
    P --> C["Cola de solicitudes<br/>(CENTER_ADMIN y ADMIN del centro)"]
    C --> D{"¿Aprobado?"}
    D -- "Aprobar" --> E["Turno definitivo +<br/>opening/closing_reviewer_admin_user = aprobador"]
    D -- "Rechazar" --> R["Queda registrado<br/>(reporte)"]
    P -.->|"No bloquea operación:<br/>check-in, ventas y débitos siguen"| OK
```

## 5. Flujo: migración one-shot a multi-tenant

```mermaid
flowchart TB
    B["1. Backup completo de la base<br/>y restaurar copia de trabajo"] --> M["2. Migraciones Flyway<br/>(ST-001…ST-005: centers, users.center_id,<br/>audit_log, center_id en tablas, uniques compuestas)"]
    M --> S["3. Script Python one-shot:<br/>- crea centro (nombre desde gym_profile, uuid v4)<br/>- asigna center_id en orden de flujo de entidades<br/>- socios semilla + CENTER_ADMIN"]
    S --> V["4. Conteos por tabla antes/después"]
    V --> K{"¿Conteos y smoke OK?"}
    K -- "Sí" --> DONE["Base multi-tenant lista<br/>(un centro con todos los datos)"]
    K -- "No" --> FB["Restaurar backup y reintentar<br/>(sin checkpoints ni reanudación)"]
```

Orden de asignación de `center_id` (ADR-0007): `centers` → `users` →
`gym_profile`/`gym_config` → `members` (+ `member_status`, fingerprints) →
`rates`/artículos → turnos → débitos → suscripciones/cortesías → check-in/out →
ventas/compras → historiales y tablas de relación.