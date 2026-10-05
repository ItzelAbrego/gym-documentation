---
id: ST-010
tipo: story
titulo: JWT con claim de centro
grupo: Adaptación
estado: pendiente
depende_de:
  - ST-001
  - ST-002
adrs:
  - ADR-0004
---

# ST-010 — JWT con claim de centro

**Grupo**: Adaptación · **Depende de**: ST-001, ST-002 · **ADRs**: [ADR-0004](../adr/ADR-0004-jwt-claim-de-centro.md)

## Historia de usuario

**Como** backend **quiero** recibir el centro del usuario en el JWT (no en la
petición) **para** que el scoping multi-tenant tenga una única fuente de verdad no
manipulable por el frontend.

## Criterios de aceptación

- [ ] `TokenProvider` agrega claims `center_uuid`, `branch_uuid` (solo si el
      usuario está asignado a una sucursal — ADR-0010; NULL para
      `ADMIN`/`CENTER_ADMIN`/`SUPERADMIN`) y `user_role` al token al hacer
      signin; los toma de `User` (hoy solo firma `username` como subject y
      `CLAIM_NAME "username"`).
- [ ] Token de superadmin: sin `center_uuid` (o `center_uuid: null`) y rol
      `SUPERADMIN`.
- [ ] El filtro de autenticación (el que hoy valida el JWT en cada request)
      extrae `center_uuid` + `branch_uuid` + `user_role` y los expone al resto
      de la app (context o detalles de autenticación) para que los servicios
      hagan scoping por centro y sucursal (ST-016).
- [ ] El frontend NO envía el UUID en headers/cuerpos: los servicios existentes
      (`auth.service.ts`, header Bearer manual) no cambian su contrato.
- [ ] El signin (`/api/v1/auth/signin`, `AuthController.java:64-87`) sigue
      devolviendo `accessToken`, `username`, `userRole` (agregar `centerUuid` y
      `centerName` para la UI si conviene).
- [ ] La expiración sigue en 4h (`plusHours(4)` en `TokenProvider`).

## Notas técnicas

- La extracción del claim vive en el filtro/security config (clase a localizar en
  `gym-api` — aún no revisada; es el componente que valida el Bearer antes de
  llegar al controller).
- `TokenProvider` tiene un fallback de secreto hardcodeado: mover el secreto a
  configuración queda como mejora adicional, no bloqueante de esta story.
