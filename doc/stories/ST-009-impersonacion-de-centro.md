---
id: ST-009
tipo: story
titulo: Impersonación de centro
grupo: Superadmin
estado: pendiente
depende_de:
  - ST-003
  - ST-006
  - ST-010
adrs:
  - ADR-0003
  - ADR-0004
---

# ST-009 — Impersonación de centro

**Grupo**: Superadmin · **Depende de**: ST-003, ST-006, ST-010 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md), [ADR-0004](../adr/ADR-0004-jwt-claim-de-centro.md)

## Historia de usuario

**Como** superadministrador **quiero** entrar a un centro con un rol de
administración temporal, con banner visible y registro de auditoría **para** dar
soporte dentro del centro sin usar sus credenciales.

## Criterios de aceptación

- [ ] `POST /api/v1/centers/{center_uuid}/impersonate` (solo `SUPERADMIN`): emite
      un nuevo JWT con `center_uuid` del centro destino, rol efectivo
      `CENTER_ADMIN` y claim adicional `impersonated_by` (username del superadmin).
- [ ] El token impersonado NO contiene las credenciales/contraseña del admin del
      centro: es un token derivado del superadmin con expiración ≤ 4h.
- [ ] `POST /api/v1/auth/exit-impersonation`: con un token impersonado, emite de
      nuevo el token del superadmin (sin centro).
- [ ] El filtro de autenticación detecta `impersonated_by` y el backend bloquea
      acciones que el impersonado no debería poder hacer: crear/editar usuarios de
      rol `CENTER_ADMIN`/`SUPERADMIN`, ver auditoría, impersonar de nuevo.
- [ ] `audit_log` registra `IMPERSONATION_START` (actor, centro, timestamp) y
      `IMPERSONATION_END`.
- [ ] Frontend: al entrar, banner fijo visible en toda la app ("Modo
      superadministrador — [Nombre del centro]") con botón "Regresar" que llama a
      `exit-impersonation` y recarga el token.
- [ ] El frontend guarda el token impersonado en el mismo `localStorage.token`
      (cambia el token, no el mecanismo de `auth.service.ts`).

## Notas técnicas

- El token se re-emite con la misma mecánica de `TokenProvider` (claims extra en
  ST-010); la expiración se recalcula al impersonar.
- Si el centro está desactivo, impersonación rechazada.
- El banner vive en el layout compartido (`app.component` / menú), no por-vista.
