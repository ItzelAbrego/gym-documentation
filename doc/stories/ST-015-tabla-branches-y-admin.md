---
id: ST-015
tipo: story
titulo: Tabla branches y administración de sucursales del centro
grupo: Principal
estado: pendiente
depende_de:
  - ST-001
  - ST-002
adrs:
  - ADR-0010
---

# ST-015 — Tabla `branches` y administración de sucursales del centro

**Grupo**: Principal · **Depende de**: ST-001, ST-002 · **ADRs**: [ADR-0010](../adr/ADR-0010-sucursales-contabilidad-aislada.md)

## Historia de usuario

**Como** centro con varias ubicaciones **quiero** registrar y administrar mis
sucursales **para** que cada una opere con su propio personal y caja.

## Criterios de aceptación

- [ ] Migración Flyway crea `branches`: `id` INT UNSIGNED auto-increment PK,
      `branch_uuid` BINARY(16) UNIQUE (identificador externo), `center_id`
      NOT NULL + FK + índice, `name`, `active`, timestamps (DDL en
      `schema-propuesta.sql`).
- [ ] Entidad `Branch` + `BranchRepository`; generación de `branch_uuid` v4.
- [ ] **Solo desactivación lógica**: `active = false`; no existe borrado físico
      (protege la contabilidad histórica — ADR-0010 regla 2).
- [ ] `users.branch_id INT NULL` + FK + índice (migración): obligatorio para
      `STAFF`/`REGISTRATION`/quiosco; NULL para `ADMIN`/`CENTER_ADMIN`/
      `SUPERADMIN`. Validación en `AuthService.signUp` (reglas por rol).
- [ ] Endpoints bajo `/api/v1/branches` (dentro del centro del token):
      `GET` lista, `POST` crear, `PUT` editar nombre, `DELETE` = desactivar.
      Accesibles para `CENTER_ADMIN` (y `ADMIN` si aplica); superadmin solo
      impersonando.
- [ ] Vista de Sucursales en el módulo centro (visible para `CENTER_ADMIN`):
      tabla con nombre, UUID, usuarios asignados, activa; alta/edición y
      desactivación con confirmación. Sección del menú de Configuración o
      página propia (decidir con el mockup).
- [ ] El alta de centro (ST-006) crea la **sucursal principal** y su usuario
      quiosco `CHECKIN_<slug>` ligado a ella (rol `REGISTRATION`).
- [ ] La migración one-shot (ST-014) crea la sucursal principal del centro
      histórico y liga a ella los usuarios operativos existentes.

## Notas técnicas

- Los usernames de quiosco deben seguir siendo únicos globalmente: derivar el
  slug del nombre del centro + sufijo de sucursal si hay varias
  (`CHECKIN_<centro>`, `CHECKIN_<centro>_<sucursal>`).
- No exponer `branches.id` en contratos: solo `branch_uuid` (igual que centros).
- La asignación de un usuario a sucursal se edita desde la vista de Usuarios
  del centro (selector de sucursal); usuarios `ADMIN`/`CENTER_ADMIN` pueden
  quedar sin sucursal.
