# Documentación de arquitectura — FitRoom SaaS

Este folder contiene la arquitectura decisional (ADRs) y las stories para convertir
FitRoom de un sistema monocentro a un **SaaS multi-tenant** (múltiples centros de gym
operando sobre el mismo backend y base de datos).

Plan de origen: `gym-documentation/Implementación de SaaS-20260918193711.md`.
Esquema de referencia: `gym-documentation/schema.sql` (esquema consolidado actual).

## Diagramas

[Diagramas de componentes y flujos](diagramas.md) — arquitectura general, login/JWT
con claim de centro, impersonación, aprobación de turnos y migración one-shot.

## Preguntas abiertas

[Preguntas y respuestas](preguntas-y-respuestas.md) — dudas vivas sobre el plan:
contradicciones detectadas entre doc base/ADRs/stories y huecos por cerrar antes
de implementar.

## Índice de ADRs

| ADR | Título | Estado |
| --- | --- | --- |
| [ADR-0001](adr/ADR-0001-arquitectura-multi-tenant.md) | Multi-tenancy con esquema compartido y columna discriminatoria `center_id` | Aceptada |
| [ADR-0002](adr/ADR-0002-identificacion-de-centros.md) | Identidad de centros: id numérico + UUID externo | Aceptada |
| [ADR-0003](adr/ADR-0003-roles-y-superadministracion.md) | Roles, superadministración e impersonación con auditoría | Aceptada |
| [ADR-0004](adr/ADR-0004-jwt-claim-de-centro.md) | JWT con claim de centro; el cliente no envía el centro | Aceptada |
| [ADR-0005](adr/ADR-0005-unicidad-de-socios-por-centro.md) | Unicidad de teléfonos y correos de socios por centro | Aceptada |
| [ADR-0006](adr/ADR-0006-aprobacion-de-turnos-fuera-de-instalaciones.md) | Aprobación de apertura/cierre de turnos con desfase | Aceptada |
| [ADR-0007](adr/ADR-0007-migracion-de-datos.md) | Migración de datos one-shot con script Python | Aceptada |
| [ADR-0008](adr/ADR-0008-sucursales-diferidas.md) | Sucursales diferidas; configuraciones ligadas a Centro | Aceptada |
| [ADR-0009](adr/ADR-0009-planes-diferidos.md) | Planes de funcionalidades por centro diferidos | Aceptada |

## Índice de stories

Las stories están en `stories/`, ordenadas por grupo y con dependencias explícitas.
El orden de implementación sugerido es el de la sección "Orden sugerido" del final.

| Story | Título | Grupo | Depende de |
| --- | --- | --- | --- |
| [ST-001](stories/ST-001-tabla-centers.md) | Tabla `centers` con id + UUID y su modelo | Principal | — |
| [ST-002](stories/ST-002-users-center-id-y-rol-center-admin.md) | `users.center_id` nullable y rol `CENTER_ADMIN` | Principal | ST-001 |
| [ST-003](stories/ST-003-tabla-audit-log.md) | Tabla `audit_log` y servicio de auditoría | Principal | ST-001 |
| [ST-004](stories/ST-004-scoping-de-tablas.md) | Agregar `center_id` al resto de las tablas | Principal | ST-001 |
| [ST-005](stories/ST-005-unicidad-de-socios-por-centro.md) | Unicidad de teléfono/correo de socios por centro | Principal | ST-004 |
| [ST-006](stories/ST-006-api-superadmin-centros.md) | API de superadmin: gestión de centros | Superadmin | ST-001, ST-002, ST-003 |
| [ST-007](stories/ST-007-vista-superadmin-centros.md) | Vista superadmin: Centros | Superadmin | ST-006, ST-011 |
| [ST-008](stories/ST-008-vista-superadmin-usuarios.md) | Vista superadmin: Usuarios | Superadmin | ST-006, ST-011 |
| [ST-009](stories/ST-009-impersonacion-de-centro.md) | Impersonación de centro con auditoría | Superadmin | ST-003, ST-006, ST-010 |
| [ST-010](stories/ST-010-jwt-claim-de-centro.md) | Claim `center_uuid` en el JWT y extracción en el filtro | Adaptación | ST-001, ST-002 |
| [ST-011](stories/ST-011-frontend-login-y-guards.md) | Adaptación de login y guards del frontend | Adaptación | ST-010 |
| [ST-012](stories/ST-012-aprobacion-de-turnos.md) | Aprobación de apertura/cierre de turnos con desfase | Adaptación | ST-002, ST-013 |
| [ST-013](stories/ST-013-scoping-de-endpoints.md) | Validación del claim de centro en endpoints existentes | Adaptación | ST-010, ST-004 |
| [ST-014](stories/ST-014-script-migracion.md) | Script de migración de datos (one-shot) | Migración | ST-001…ST-005 |

## Orden sugerido de implementación

1. **Fundaciones**: ST-001 → ST-002 → ST-003 → ST-004 → ST-005 → ST-010 → ST-013
2. **Superadmin**: ST-006 → ST-011 → ST-007 → ST-008 → ST-009
3. **Adaptación funcional**: ST-012
4. **Migración** (fase posterior, con datos reales): ST-014

## Estado de la revisión de código (2026-09-21)

Verificado directamente (archivos leídos):

- `gym-api/pom.xml` — Spring Boot 3.2.5, Java 17, Flyway 10.9.1, `com.auth0/java-jwt` 4.4.0, Spring Security, SourceAFIS.
- `gym-api/src/main/resources/application.yml` — context-path `/fit-room-gym`, JWT secret por env, jobs programados (tarifas, suscripciones, cortesías a medianoche).
- `com/fitroom/gym/controller/AuthController.java` — `/api/v1/auth/signin` retorna `accessToken`, `username`, `userRole`; `/signup` lista/desactiva usuarios.
- `com/fitroom/gym/controller/MemberController.java` — `/api/member` (crear/actualizar socios, sin scoping).
- `com/fitroom/gym/controller/WorkShiftController.java` — `/api/work-shift/open` y close, sin scoping.
- `com/fitroom/gym/service/TokenProvider.java` — HMAC256, subject = username, único claim `username`, expiración 4 h.
- `com/fitroom/gym/service/AuthService.java` — `UserDetailsService`, registro con BCrypt, unicidad de username.
- `com/fitroom/gym/entity/User.java` + `entity/UserRole.java` — roles actuales `ADMIN`, `USER`, `REGISTRATION`; `ADMIN` hereda authorities de `USER` y `REGISTRATION`.
- `com/fitroom/gym/entity/Member.java` — `cell_phone` y `email` con UNIQUE.
- `com/fitroom/gym/service/MemberService.java` — validaciones de duplicado de teléfono/correo globales (`validateDuplicateCellPhoneMember`, `validateDuplicateEmailMember`); `checkMemberByCellPhone` para check-in.
- `com/fitroom/gym/service/CheckInService.java` — check-in/out desde `SecurityContextHolder`; validación de membresía activa del socio.
- `com/fitroom/gym/entity/WorkShift.java` + `service/WorkShiftService.java` — apertura/cierre con revisor aprobador `ADMIN`.
- `com/fitroom/gym/entity/DebitTransaction.java` — cancelación con `admin_user_cancellation_approval`.
- `com/fitroom/gym/entity/CheckIn.java` — `register_timestamp` con UNIQUE global (riesgo de colisión entre centros).
- `com/fitroom/gym/entity/Subscription.java` — referencia a `Member` y `DebitTransaction` (scoping se hereda del miembro).
- `com/fitroom/gym/entity/GymProfile.java` + `service/GymConfigService.java` — perfil y configuraciones globales, sin centro.
- `com/fitroom/gym/repository/UserRepository.java` — búsquedas globales por username.
- `com/fitroom/gym/repository/MemberRepository.java` — `findByCellPhone(String)` y `findByEmail(String)` globales (sin centro); búsqueda paginada `findByFilters`.
- `com/fitroom/gym/repository/WorkShiftRepository.java` — `findOpenWorkShift()` (un turno abierto global, sin filtro por centro).
- `gym-web/src/app/services/auth.service.ts` — token, username y userRole en `localStorage`; header Bearer por petición.
- `gym-web/src/app/guards/auth.guard.ts` — compara `userRole === 'ADMIN'`.
- `gym-web/src/app/shared/menu-items/menu-items.ts` — menú por rol: ADMIN ve todo (menos páginas deshabilitadas por `gym_config`), REGISTRATION solo Check-In, USER ve un subconjunto.
- `schema.sql` — esquema completo actual (ver referencias por tabla en cada ADR).

Pendiente de confirmar (los ADRs los referencian sin ruta):

- Clase con `SecurityFilterChain` y el filtro `OncePerRequestFilter` que valida el JWT por petición (cómo propaga el usuario autenticado).
- `DefaultAdminInitializer` (crea el admin inicial al arrancar, según comentario en `schema.sql`).
- Jobs de expiración (`scheduler`) — lógica por centro a introducir.
