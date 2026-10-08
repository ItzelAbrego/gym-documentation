# Análisis de cobertura — Stories SaaS vs. Tickets del backlog

**Fecha:** 2026-09-22 · **Actualizado:** 2026-10-08 (reconciliación en vivo contra ClickUp)
**Alcance:** comparación de las 16 historias de [`doc/stories/`](stories/) (ST-001…ST-016) contra
los tickets ya creados en ClickUp (espacio `Fit-Manage`). Los tickets SaaS están
repartidos en dos listas: [`Migration SaaS`](https://app.clickup.com/90131366728/v/li/1400320000003608)
(`1400320000003608`, núcleo BD/migración/sucursales) y
[`Backlog`](https://app.clickup.com/90131366728/v/li/901319078469) (`901319078469`,
API superadmin, frontend, auth y operativos).
**Objetivo:** identificar qué está cubierto, qué falta y qué está desalineado, para
revisar con calma y decidir acciones (crear/editar/aclarar tickets).

> Nota: los tickets del backlog actualmente tienen **solo título, sin descripción**.
> Las historias `ST-*` sí tienen criterios de aceptación detallados y referencias a
> archivos/líneas del código. Este documento asume esa asimetría como uno de los
> hallazgos.

---

## 1. Mapeo por historia

| Story | Tema | Tickets en backlog | Cobertura |
| --- | --- | --- | --- |
| [**ST-001**](stories/ST-001-tabla-centers.md) Tabla `centers` | BD centros | [Crear tabla de centros (centers)](https://app.clickup.com/t/86abyr0er) | ✅ Parcial (falta entidad/UUID/repo explícito) |
| [**ST-002**](stories/ST-002-users-center-id-y-rol-center-admin.md) `users.center_id` + rol `CENTER_ADMIN` | BD/roles | [users.center_id nullable + rol CENTER_ADMIN](https://app.clickup.com/t/86abyr0nj) | ✅ Alineada (2026-09-22) |
| [**ST-003**](stories/ST-003-tabla-audit-log.md) Tabla `audit_log` + servicio | Auditoría | [audit_log de acciones de sistema](https://app.clickup.com/t/86ac9522n) | ✅ Alineada (2026-09-22) |
| [**ST-004**](stories/ST-004-scoping-de-tablas.md) `center_id` en el resto de tablas | Scoping BD | [center_id en el resto de las tablas](https://app.clickup.com/t/17tjnm2rtz6) | ✅ Ticket creado (2026-09-22) |
| [**ST-005**](stories/ST-005-unicidad-de-socios-por-centro.md) Unicidad socios por centro | BD constraint | [Unicidad de socios por centro](https://app.clickup.com/t/17tjnm2rtz9) | ✅ Ticket creado (2026-09-22) |
| [**ST-006**](stories/ST-006-api-superadmin-centros.md) API superadmin centros | Backend | [Endpoint crear](https://app.clickup.com/t/86abyyy24) · [Servicio crear](https://app.clickup.com/t/86abyyvyc) · [Endpoint editar](https://app.clickup.com/t/86abyyzau) · [Servicio editar](https://app.clickup.com/t/86abyyz13) · [Endpoint desactivar](https://app.clickup.com/t/86abyz0du) · [Query desactivar](https://app.clickup.com/t/86abyz03p) · [Endpoint listar](https://app.clickup.com/t/86abyyup9) · [Query listar](https://app.clickup.com/t/86abyyt1d) | ✅ Bien cubierta |
| [**ST-007**](stories/ST-007-vista-superadmin-centros.md) Vista superadmin Centros | Frontend | [Crear centro](https://app.clickup.com/t/86ac1gu4w) · [Editar centro](https://app.clickup.com/t/86ac1guw9) · [Catálogo centros](https://app.clickup.com/t/86ac1gueh) · [Desactivar centro](https://app.clickup.com/t/86ac1gv61) · [Portal superadmin](https://app.clickup.com/t/86ac1gtm9) | ✅ Bien cubierta |
| [**ST-008**](stories/ST-008-vista-superadmin-usuarios.md) Vista superadmin Usuarios | Frontend | [Crear usuario](https://app.clickup.com/t/86ac1gw9d) · [Editar usuario](https://app.clickup.com/t/86ac1gxgf) · [Catálogo usuarios](https://app.clickup.com/t/86ac1gwrd) · [Eliminar usuario](https://app.clickup.com/t/86ac1gy8d) | ✅ Cubierta |
| [**ST-009**](stories/ST-009-impersonacion-de-centro.md) Impersonación de centro | Full-stack | [ST-009 Impersonación de centro](https://app.clickup.com/t/17tjnm2vmtq) | ✅ Ticket creado (2026-10-08) |
| [**ST-010**](stories/ST-010-jwt-claim-de-centro.md) JWT claim de centro | Backend auth | [Cambios de autenticación backend](https://app.clickup.com/t/86ac1y5yu) · [Actualización de autenticación](https://app.clickup.com/t/86ac1gz7t) (⚠️ duplicado) | ✅ Enriquecido (2026-10-08); consolidar duplicado 86ac1gz7t |
| [**ST-011**](stories/ST-011-frontend-login-y-guards.md) Frontend login + guards | Frontend | [Cambios de autenticación frontend](https://app.clickup.com/t/86ac1y6pw) | ✅ Enriquecido (2026-10-08) |
| [**ST-012**](stories/ST-012-aprobacion-de-turnos.md) Aprobación de turnos fuera de horario | Full-stack | [ST-012 Aprobación de turnos](https://app.clickup.com/t/17tjnm2vmtr) | ✅ Ticket creado (2026-10-08) |
| [**ST-013**](stories/ST-013-scoping-de-endpoints.md) Scoping de endpoints/servicios | Backend | [ST-013 Scoping multi-tenant](https://app.clickup.com/t/86abyarpa) | ✅ Enriquecido y renombrado (2026-10-08) |
| [**ST-014**](stories/ST-014-script-migracion.md) Script migración one-shot | Migración | [ST-014 Script de migración one-shot](https://app.clickup.com/t/17tjnm2vmtw) | ✅ Ticket creado (2026-10-08) |
| [**ST-015**](stories/ST-015-tabla-branches-y-admin.md) Tabla `branches` + admin sucursales | BD/full-stack | [ST-015 Tabla branches y admin](https://app.clickup.com/t/17tjnm2vmtt) | ✅ Ticket creado (2026-10-08) |
| [**ST-016**](stories/ST-016-scoping-por-sucursal.md) `branch_id` + stock por sucursal | BD/backend | [ST-016 branch_id y stock por sucursal](https://app.clickup.com/t/17tjnm2vmtv) | ✅ Ticket creado (2026-10-08) |

---

## 2. Tickets antes sueltos — ✅ ASIGNADOS A STORY (2026-10-08)

Se renombraron con prefijo `ST-NNN —` y se confirmó su épica/padre:

- **API de usuarios superadmin → ST-008** (son el backend de la vista de usuarios
  superadmin; bajo épica Superadministrador `86abyarnh`):
  [API Endpoint crear usuario](https://app.clickup.com/t/86ac999vh),
  [API Endpoint listar por filtros](https://app.clickup.com/t/86ac999bt),
  [API Consulta listar por filtros](https://app.clickup.com/t/86ac9999w).
- **Scoping de endpoints existentes → ST-013** (bajo `86abyarpa` = ST-013):
  usuarios ([Eliminar](https://app.clickup.com/t/86ac997b6),
  [Obtención](https://app.clickup.com/t/86ac9979z),
  [Creación](https://app.clickup.com/t/86ac99799)) y
  operativos de socios/suscripciones ([Nueva suscripción](https://app.clickup.com/t/86acb9pn9),
  [Lista de socios](https://app.clickup.com/t/86acb9meh),
  [Editar socio](https://app.clickup.com/t/86acb9g1t),
  [Registro de socio](https://app.clickup.com/t/86ac997df)).

> **Corrección aplicada (2026-10-08):** el ticket
> [86ac99799](https://app.clickup.com/t/86ac99799) describía la creación de usuario
> usando una tabla puente `center_users`. Se reescribió para usar `users.center_id`
> (decisión §3.1 / ST-002). Fuente de verdad = repositorio.

- **[Crear interceptor para headers comunes](https://app.clickup.com/t/86ac994qk)**:
  ✅ revisado (2026-10-08) — es solo refactor del header `Authorization` en el
  frontend; **no** reintroduce el centro por header. Ver §3.
- **Épicas / agrupadores**
  ([Superadministrador](https://app.clickup.com/t/86abyarnh),
  [Centros](https://app.clickup.com/t/86abyarn7) — initiative,
  [Migración a SaaS](https://app.clickup.com/t/86abedxet)):
  contenedores; sirven como épica padre de las historias colgadas.

---

## 3. Desalineaciones a resolver (decisiones abiertas)

1. ~~**`center_users` (tabla puente) vs. `users.center_id` (columna).**~~
   ✅ **Resuelta (2026-09-22):** la documentación es la fuente de verdad → se adopta
   `users.center_id` nullable (0..1) y se descarta `center_users`. El ticket
   [86abyr0nj](https://app.clickup.com/t/86abyr0nj) fue renombrado y reescrito
   conforme a [ST-002](stories/ST-002-users-center-id-y-rol-center-admin.md).

2. ~~**Alcance de `audit_log`.**~~
   ✅ **Resuelta (2026-09-22):** se re-enfocó a **acciones de sistema** (impersonación,
   alta/baja de centros y usuarios), no CRUD operativo. El ticket
   [86ac9522n](https://app.clickup.com/t/86ac9522n) fue renombrado a "audit_log de
   acciones de sistema" y descrito conforme a
   [ST-003](stories/ST-003-tabla-audit-log.md).

3. ~~**Centro en headers vs. en JWT.**~~
   ✅ **Resuelta (2026-10-08):** se revisó la descripción real de
   [Crear interceptor para headers comunes](https://app.clickup.com/t/86ac994qk) y
   **no hay conflicto** con [ADR-0004](adr/ADR-0004-jwt-claim-de-centro.md)/[ST-010](stories/ST-010-jwt-claim-de-centro.md).
   El ticket es un refactor de frontend que centraliza el header `Authorization` ya
   existente; no reintroduce el centro por header. Se agregó un criterio de aceptación
   defensivo al ticket: el interceptor maneja solo `Authorization`/`Content-Type` y
   `center_uuid`/`branch_uuid` viajan únicamente en el claim del JWT.

---

## 4. Historias sin ticket — ✅ RESUELTO (2026-10-08)

Todos los huecos de §1 fueron cubiertos con tickets en la lista
[`Migration SaaS`](https://app.clickup.com/90131366728/v/li/1400320000003608):

- [**ST-015**](https://app.clickup.com/t/17tjnm2vmtt) tabla `branches` + admin de
  sucursales y [**ST-016**](https://app.clickup.com/t/17tjnm2vmtv) `branch_id`/stock
  por sucursal — modelo de sucursales (ADR-0010 reemplaza al ADR-0008 diferido;
  **las sucursales SÍ entran en este alcance**, confirmado 2026-10-08).
- [**ST-009**](https://app.clickup.com/t/17tjnm2vmtq) impersonación de centro
  (bajo épica Superadministrador).
- [**ST-012**](https://app.clickup.com/t/17tjnm2vmtr) aprobación de turnos fuera de
  horario.
- [**ST-014**](https://app.clickup.com/t/17tjnm2vmtw) script de migración one-shot
  (bloquea go-live).
- **Renombre `USER → STAFF` + roles `SUPERADMIN`/`CENTER_ADMIN`**: subtarea
  [17tjnm2vmtx](https://app.clickup.com/t/17tjnm2vmtx) colgada de ST-002
  ([86abyr0nj](https://app.clickup.com/t/86abyr0nj)), enfocada a la propagación en
  frontend (`auth.guard.ts`, `menu-items.ts`) y código, que ST-002 no trackeaba.

> ST-004 y ST-005 ya tenían ticket desde 2026-09-22.

### Decisión de alcance registrada (2026-10-08)
- **Solo `SUPERADMIN` impersona / cruza entre centros.** `ADMIN` y `CENTER_ADMIN`
  tienen `center_id` fijo y quedan confinados a su centro por el scoping del JWT
  (ADR-0003/ADR-0004). Lo más cercano a un cambio de contexto para
  `ADMIN`/`CENTER_ADMIN` es elegir entre sucursales **de su propio centro** (ST-016).

---

## 5. Acciones (estado 2026-10-08)

- [x] **Crear tickets faltantes**: ST-009, ST-012, ST-014, ST-015, ST-016 creados en
      `Migration SaaS`; renombre de roles como subtarea de ST-002. (ST-004/ST-005 ya
      existían.)
- [x] **Enriquecer tickets existentes** vacíos de auth/scoping con los criterios de la
      story: ST-010 (86ac1y5yu), ST-011 (86ac1y6pw), ST-013 (86abyarpa renombrado).
      Pendiente menor: consolidar/cerrar el duplicado 86ac1gz7t de ST-010.
- [x] **Resolver decisiones** (§3): center_users (resuelta 09-22), audit_log (resuelta
      09-22), interceptor vs JWT (resuelta 10-08).
- [ ] **Enriquecer** aún los tickets de ST-001/ST-006/ST-007/ST-008 (existen pero con
      descripción breve); no bloqueante.
- [x] **Marcar/colgar de épicas**: tickets nuevos parentados a `Migración a SaaS`
      (86abedxet) y `Superadministrador` (86abyarnh); `Centros` (86abyarn7) es
      initiative.
- [x] **Vincular** los operativos de socios/suscripciones y la API de usuarios
      superadmin (§2): renombrados con prefijo `ST-NNN —` y confirmada su épica
      (ST-008 bajo Superadministrador; scoping bajo ST-013). Corregido el ticket
      86ac99799 (quitada la referencia a `center_users`).
- [x] **Normalizar títulos**: todos los tickets 1:1 y sub-tareas llevan prefijo
      `ST-NNN —` para visibilidad; el duplicado 86ac1gz7t marcado como
      `(DUPLICADO)`.

> **Avance real de implementación:** salvo ST-001 (86abyr0er, en *pull request*),
> todos los demás tickets siguen en *to do*. El backlog SaaS está casi completamente
> especificado pero la implementación está en etapa inicial.

---

## Anexo — Referencias

- Stories: [`doc/stories/`](stories/) (ST-001…ST-016)
- ADRs: [`doc/adr/`](adr/) (ADR-0001…ADR-0010)
- Índice y orden sugerido: [`doc/README.md`](README.md)
- Backlog ClickUp: [espacio `Fit-Manage` → lista `Backlog`](https://app.clickup.com/90131366728/v/li/901319078469) (`901319078469`)
