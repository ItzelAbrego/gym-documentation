---
id: ST-011
tipo: story
titulo: Frontend, login, guards y menú multi-rol
grupo: Adaptación
estado: pendiente
depende_de:
  - ST-010
adrs:
  - ADR-0003
  - ADR-0004
---

# ST-011 — Frontend: login, guards y menú multi-rol

**Grupo**: Adaptación · **Depende de**: ST-010 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md), [ADR-0004](../adr/ADR-0004-jwt-claim-de-centro.md)

## Historia de usuario

**Como** usuario de cualquier rol (superadmin, admin de centro, staff,
registration) **quiero** que el frontend me dirija al módulo que me corresponde y
me muestre el menú de mi rol **para** trabajar sin ver funciones ajenas.

## Criterios de aceptación

- [ ] `AuthGuard` (`guards/auth.guard.ts`, hoy solo acepta `ADMIN` en línea 23)
      acepta `SUPERADMIN` y `CENTER_ADMIN` (los tres pasan donde hoy pasa `ADMIN`).
- [ ] Routing por rol tras login: `SUPERADMIN` → módulo superadmin (ST-007/008);
      `CENTER_ADMIN`/`ADMIN` → vistas de centro; los demás roles igual que hoy.
- [ ] Menú (`shared/menu-items/menu-items.ts`): nueva página de superadmin visible
      solo para `SUPERADMIN`; reglas de `getMenuitem()` extendidas con los roles
      nuevos (mismo patrón de ocultamiento que hoy para `USER`/`REGISTRATION`).
- [ ] Guard de rutas del módulo superadmin que rechace a cualquier rol que no sea
      `SUPERADMIN`.
- [ ] El servicio de auth guarda `centerUuid` (si viene) junto a
      `token`/`username`/`userRole` en localStorage y lo usa para mostrar el
      nombre del centro en la UI (no para enviarlo al backend).
- [ ] El timer de logout a 4h (`auth.service.ts`) se mantiene.

## Notas técnicas

- Los roles en el token/respuesta llegan como `userRole` string; usar los valores
  del enum de backend (`SUPERADMIN`, `CENTER_ADMIN`, `ADMIN`, `STAFF`,
  `REGISTRATION`) — ojo con el mapeo minúsculas/mayúsculas actual y con el
  renombre `USER`→`STAFF` (P-06) en guardas y menú.
