---
id: ST-008
tipo: story
titulo: Vista superadmin de usuarios de todos los centros
grupo: Superadmin
estado: pendiente
depende_de:
  - ST-006
  - ST-011
adrs:
  - ADR-0003
---

# ST-008 — Vista superadmin: Usuarios (todos los centros)

**Grupo**: Superadmin · **Depende de**: ST-006, ST-011 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** superadministrador **quiero** ver y administrar los usuarios de todos los
centros con filtros **para** dar soporte y corregir accesos sin entrar a cada centro.

## Criterios de aceptación

- [ ] Vista de Usuarios en el módulo superadmin: lista paginada de TODOS los
      usuarios, con **sin filtro por defecto** (plan de origen).
- [ ] Filtros: por rol (`SUPERADMIN`, `CENTER_ADMIN`, `ADMIN`, `STAFF`,
      `REGISTRATION` — ojo al renombre `USER`→`STAFF`, P-06), por nombre/username
      y por centro.
- [ ] Creación de `CENTER_ADMIN` para cualquier centro (selector de centro en el
      formulario); se registra `USER_CREATED` en `audit_log`.
- [ ] Los superadmins no son editables entre sí (ni se desactivan entre ellos).
- [ ] Un usuario de centro (`CENTER_ADMIN`) puede editar/crear usuarios solo de su
      centro (comportamiento actual de `ADMIN` en `/signup`, acotado a su centro).
- [ ] La columna de centro identifica a qué centro pertenece cada usuario;
      superadmins aparecen como "—".

## Notas técnicas

- El listado actual de usuarios viene de `GET /signup` con paginación
  (`AuthController.java`); extender con filtros `role`, `center_uuid`, `keyword`
  y visibilidad por rol (superadmin ve todo, `CENTER_ADMIN` solo su centro).
- `getAuthorities()` de `User.java:53-65` determina qué ve cada rol; la vista
  respeta la jerarquía de ADR-0003.
