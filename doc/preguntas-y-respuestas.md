# Preguntas y respuestas — Conversión a SaaS multi-tenant

Documento vivo de dudas sobre la conversión de FitRoom a SaaS. Fuente de verdad
inicial: `gym-documentation/Implementación de SaaS-20260918193711.md` (doc base).
Las decisiones ya cerradas viven en los [ADRs](./adr/); este documento recoge lo que
**aún está abierto o es contradictorio** y, conforme se responde, la respuesta queda
registrada aquí y se propaga a ADRs/stories.

Estado al 2026-09-21 (tercera revisión: ronda de preguntas con el solicitante).

---

## Contradicciones detectadas

### C-01 — ¿Un turno pendiente de aprobación bloquea la operación?

**Doc base**: solo pide aprobación del administrador ante cierres/aperturas con
desfase; no dice nada sobre bloquear.

**Conflicto en la documentación actual**:

- [ADR-0006](./adr/ADR-0006-aprobacion-de-turnos-fuera-de-instalaciones.md) regla 4:
  *"Mientras un turno esté `PENDING_APPROVAL` **no se registran transacciones nuevas**
  contra él."*
- [ST-012](./stories/ST-012-aprobacion-de-turnos.md), criterio: *"Los turnos
  pendientes **NO bloquean**: check-ins, ventas y débitos siguen operando."*
- [Diagrama 4](./diagramas.md) coincide con ST-012 (no bloquea).

**Impacto**: cambia el diseño de `WorkShiftService` y la experiencia del staff
(bloquear caja de un gym por un desfase legítimo es un daño operativo real).

**Recomendación**: **NO bloquea**. Es la lectura más fiel al doc base (que concibe
la aprobación como control posterior, no como candado), ya lo asumen ST-012 y el
diagrama, y bloquear la caja por un turno atípico legítimo degrada la operación del
cliente. Al cerrarla así, corregir la regla 4 de ADR-0006.

**Respuesta**: ☑ **Decidido: NO bloquea.** Un turno
`PENDING_APPROVAL` no detiene la operación: check-ins, ventas y débitos siguen
registrándose; la aprobación es control posterior, no candado. **Acción**: corregir
la **regla 4 de ADR-0006** para alinearla con ST-012 y el Diagrama 4.

---

## Autenticación y usuarios

### P-02 — ¿Qué notificaciones recibe el `CENTER_ADMIN` y por qué canal?

**Doc base**: el administrador de centro *"necesita proporcionar su correo
electrónico para notificaciones importantes."*

**Parcialmente resuelto**: el correo queda cubierto por P-01 (`username` ES el
correo; ver tabla de resueltas).

**Sigue abierto**: qué eventos notifican (¿solicitudes de aprobación de turnos?,
¿aviso de desactivación del centro?, ¿temas de facturación del SaaS?) y por qué
canal en esta fase (¿correo?, ¿solo aviso en pantalla como ya decide ST-012 para
turnos?). Sugerencia: en esta fase, solo avisos en pantalla; correo diferido con la
fase de planes (ADR-0009).

**Respuesta**: ☑ **Esta fase: solo avisos en pantalla** (sin correo). Los eventos
en pantalla incluyen las solicitudes de aprobación de turnos (ST-012) y el estado
del centro. El **correo** para notificaciones importantes (aprobaciones,
desactivación de centro, facturación) se **difiere** a la fase de planes (ADR-0009),
donde ya existe el canal de facturación (G2).

---

### P-05 — "El `CENTER_ADMIN` no puede ser afectado por otros usuarios"

**Doc base**: el administrador de centro *"no puede ser afectado por otros
usuarios."*

**Hueco**: la frase no está operativizada en ninguna story. Casos concretos sin
respuesta:

1. ¿Un `ADMIN` del mismo centro puede editar/desactivar a un `CENTER_ADMIN`?
2. ¿Un `CENTER_ADMIN` puede editar/desactivar a **otro** `CENTER_ADMIN` del
   mismo centro? (el doc base permite varios por centro)
3. ¿Quién puede quitar el rol `CENTER_ADMIN`? (otorgarlo ya está decidido: solo
   el superadmin — ADR-0003 — pero ¿revocarlo?)

**Opciones**:

- **Opción A — Solo el superadmin**: ni un `ADMIN` ni otro `CENTER_ADMIN` del
  centro pueden editar/desactivar/degradar a un `CENTER_ADMIN`; todo cambio sobre
  ese rol pasa por superadministración (con `audit_log`).
- **Opción B — `CENTER_ADMIN` entre sí**: un `CENTER_ADMIN` puede gestionar a
  otros `CENTER_ADMIN` de su mismo centro (edición y desactivación, no otorgar el
  rol a nuevos). Más autonomía del centro, menos dependencia del superadmin.

**Recomendación**: **Opción A**. Es la lectura literal del doc base ("no puede ser
afectado por otros usuarios"), concentra el poder sobre el rol crítico en quien ya
tiene auditoría obligatoria, y evita que un `CENTER_ADMIN` malintencionado (o su
cuenta comprometida) desactive a los demás administradores del centro. Costo:
cada baja/cambio de `CENTER_ADMIN` requiere al superadmin — fricción aceptable por
ser un evento raro.

**Impacto al decidir**: ST-002, ST-008 y el endpoint `/api/v1/auth/signup` +
edición de usuarios. Si gana B, decidir además si el auditoría del cambio es
suficiente vía tablas operativas o requiere `audit_log`.

**Respuesta**: ☑ **Decidido: Opción A — solo el superadmin** puede
editar/desactivar/degradar a un `CENTER_ADMIN`. Ni un `ADMIN` ni otro
`CENTER_ADMIN` del mismo centro pueden afectar a un `CENTER_ADMIN`. Todo cambio
sobre ese rol pasa por superadministración y se registra en `audit_log`
(`USER_ROLE_CHANGED`). **Acción**: aplicar la regla en `AuthService.signUp` +
edición de usuarios (ST-002, ST-008).

---

### P-12 — ¿Cuál es la diferencia entre `ADMIN` y `CENTER_ADMIN`? ¿La migración debe promover todos los `ADMIN` a `CENTER_ADMIN`?

**Contexto**: la rama `Center-feature-branch` incluye la migración
`V202403121694__replace_admin_to_center_admin.sql`, que ejecuta
`UPDATE users SET user_role = 'CENTER_ADMIN' WHERE user_role = 'ADMIN'`, es decir
**promueve en masa a todos los `ADMIN` existentes a `CENTER_ADMIN`**. Surge la
duda de si eso es correcto y qué distingue realmente a ambos roles.

**Diferencia documentada** (ya está en [ADR-0003](./adr/ADR-0003-roles-y-superadministracion.md)):

| | `CENTER_ADMIN` | `ADMIN` |
| --- | --- | --- |
| Qué es | Usuario **principal** del centro; **renombre del antiguo rol "Billing"** del plan de origen | Administrador **operativo** del centro (rol ya existente hoy) |
| Gestión de usuarios | Crea usuarios y **cambia roles** dentro de su centro | Crea usuarios operativos; no gestiona el rol crítico `CENTER_ADMIN` |
| Jerarquía (`getAuthorities()`) | `CENTER_ADMIN` → `ADMIN` + `STAFF` + `REGISTRATION` (por encima de ADMIN) | `ADMIN` → `STAFF` + `REGISTRATION` |
| `branch_id` | NULL (ámbito de todo el centro) | NULL (ámbito de todo el centro) |
| Otorgamiento del rol | **Solo un superadmin** lo concede (ver P-05) | Lo puede crear un `CENTER_ADMIN` del centro |
| Cantidad por centro | Varios | Varios |

En resumen: `CENTER_ADMIN` es el **responsable/dueño** del centro (el antiguo
*Billing*: recibe notificaciones importantes y responde por el centro); `ADMIN`
es un **administrador operativo** por debajo de él. Ambos abarcan todo el centro,
pero `CENTER_ADMIN` está jerárquicamente arriba y su rol solo lo concede el
superadmin.

**Respuesta**: la promoción masiva **contradice el ADR-0003**, que es explícito:

- §Decisión.2: *"`CENTER_ADMIN` — **renombra al antiguo 'Billing'**"* (no "renombra
  a ADMIN").
- §Consecuencias: *"Los usuarios con rol `ADMIN` existentes **no cambian**; solo se
  agregan roles nuevos."*

Por tanto:

1. Los `ADMIN` actuales **permanecen como `ADMIN`**.
2. `CENTER_ADMIN` es un rol **nuevo** (ex-Billing), no una promoción automática.
3. El `CENTER_ADMIN` del centro histórico se **designa explícitamente** (vía
   `DefaultAdminInitializer` / script de migración ST-014, o designación manual
   del responsable), **no** promoviendo a todos los `ADMIN`.
4. **Acción pendiente**: corregir/reemplazar la migración
   `V202403121694__replace_admin_to_center_admin.sql` para que **no** haga el
   `UPDATE` masivo. Confirmar con el autor del PR #438 si hubo una razón de
   negocio (p. ej. que en el gym original el "dueño" operaba como `ADMIN` y hay
   que designar a **uno** de ellos como `CENTER_ADMIN`, no a todos).

**Estado**: ☑ Respondida (fuente: ADR-0003). Queda abierta solo la **acción de
corrección** de la migración `V1694`.

---

## Sucursales — alcance de roles

### P-13 — ¿Un `ADMIN` puede ver todas las sucursales o debe acotarse a una?

**Contexto**: [ADR-0010](./adr/ADR-0010-sucursales-contabilidad-aislada.md) §5 y §8
ponen a `ADMIN` y `CENTER_ADMIN` en el mismo nivel de alcance: ambos operan
**todo el centro** (`branch_id` NULL). Solo `STAFF` y `REGISTRATION` (incl.
quioscos) quedan atados a una sucursal. Esto deja un hueco para el caso de negocio
"gerente de una sola sucursal" (un administrador de sede que NO debe ver las demás
sucursales): hoy ese rol no existe.

**Opciones**:

- **Opción 1 — Dejarlo como está**: `ADMIN` = todo el centro. Válido para centros
  de una sola sucursal o donde el admin gestiona todas las sedes.
- **Opción 2 — Acotar `ADMIN` por sucursal (elegida)**: permitir que un `ADMIN`
  lleve `branch_id`; si lo tiene, su alcance se limita a esa sucursal; si es NULL,
  mantiene el ámbito de todo el centro (retrocompatible). Reutiliza
  `users.branch_id` (ya existe, ADR-0010 §5), el claim `branch_uuid` del JWT
  (ST-010/ST-016) y el scoping por sucursal que ya se construye para
  `STAFF`/`REGISTRATION` (ST-016); no agrega tablas ni roles nuevos.
- **Opción 3 — Rol nuevo `BRANCH_ADMIN`**: deja `ADMIN` como centro-completo y crea
  un rol intermedio ligado a sucursal. Más limpio conceptualmente, pero agrega un
  rol al modelo y más trabajo.

**Respuesta**: ☑ **Opción 2** — `ADMIN` puede quedar acotado a una sucursal vía
`branch_id`. Regla de alcance:

- `ADMIN` con `branch_id` != NULL → ve/opera **solo** esa sucursal (igual que
  `STAFF`/`REGISTRATION` en el scoping, pero con permisos de administrador).
- `ADMIN` con `branch_id` NULL → ve/opera **todo el centro** (comportamiento
  actual, retrocompatible).
- `CENTER_ADMIN` siempre abarca el centro completo (sin cambio).

**Impacto**:

- **ADR-0010 §5 y §8**: documentar que `ADMIN` puede llevar `branch_id` y que su
  alcance depende de si está o no asignado a una sucursal.
- **ST-015**: `AuthService.signUp` debe permitir (opcionalmente) asignar sucursal a
  un `ADMIN`; la vista de Usuarios del centro ofrece el selector de sucursal también
  para `ADMIN` (hoy pensado solo para `STAFF`/`REGISTRATION`).
- **ST-016**: el scoping por sucursal debe contemplar desde el diseño que un `ADMIN`
  puede estar acotado a una sucursal (no asumir que `ADMIN` siempre es
  centro-completo). Mismo nivel de mitigación de "query sin filtro de sucursal =
  mezcla" que ya aplica a `STAFF`.
- **Momento**: decidir e incorporar **antes** de implementar ST-016 para no
  parchear el scoping después.

**Estado**: ☑ Respondida (Opción 2). Pendiente propagar a ADR-0010, ST-015 y ST-016.

---

## Planes del SaaS — nombre

### P-08 — Colisión del nombre "Planes"

**Contexto**: en las vistas actuales del gym existe "Planes" (planes/membresías
que se venden a socios → `membership_config`, `rates`). El doc base usa "planes"
para el plan comercial del SaaS por centro. Son conceptos distintos con el mismo
nombre.

**Pregunta**: ¿se renombra alguno cuando entre la fase de planes
([ADR-0009](./adr/ADR-0009-planes-diferidos.md))? Candidatos: "Plan SaaS" / "Plan
de centro" para lo nuevo; "Membresías" para lo vendido a socios.

**Respuesta**: ☑ **Diferido a la fase de planes (G2), con nomenclatura ya
acordada**: lo nuevo del SaaS se llamará **"Plan de centro"** y lo que se vende a
socios pasará a **"Membresías"**. El renombrado efectivo (UI + código) se ejecuta
junto con la fase de planes (ADR-0009); por ahora solo queda registrada la
decisión de nombres.

---

## Ciclo de vida del centro

### P-09 — Borrado físico asíncrono de centros

**Doc base**: *"Se debe considerar el borrado por pasos (borrado lógico y
borrado 'físico' asíncrono)."*

**Estado actual**: lógico cubierto (`active = false`, ST-006; tokens rechazados,
ST-013). El físico quedó *"asíncrono/manual fuera de esta fase"* sin definir
nada.

**Preguntas por cerrar** (aunque se difiera la implementación):

1. ¿Quién dispara el borrado físico y con qué antelación tras la desactivación?
2. ¿Se entrega/exporta la información al cliente antes de borrar (respaldos,
   reportes)?
3. ¿Se borran también los `users` del centro o se conservan deshabilitados?

**Respuesta**: ☑ **Esta fase: solo borrado lógico** (`active = false`). El borrado
físico se **difiere** (G2/G5) como job manual/asíncrono, con política ya acordada
para cuando se implemente:

1. Lo **dispara el superadmin** manualmente, tras un período de gracia desde la
   desactivación (valor por definir al implementar, p. ej. 30–90 días).
2. **Sí**: se exporta/entrega la información del cliente (respaldo + reportes)
   **antes** de borrar.
3. Los `users` del centro **se conservan deshabilitados**, no se borran, para no
   romper las FK de `audit_log` ni la trazabilidad histórica (G5).

---

### P-10 — `gym_profile`: ¿fusionar con `branches` o extensión?

**Doc base** ("Nota sobre gym_profile"): *"candidata a fundirse con la tabla
centers… o a quedar como su extensión ligada por `center_id`. Se decide al
implementar."*
[ADR-0002](./adr/ADR-0002-identificacion-de-centros.md) eligió extensión ligada
al centro, pero tras la revisión del PR cambió a **extensión ligada a `branch_id`**
(ADR-0010): cada sucursal física tiene su propio nombre, teléfono y dirección.
La pregunta pasa a: ¿fusionar `gym_profile` con `branches` o mantenerla como
extensión?

**Estado**: sigue abierto deliberadamente. Decidir antes de implementar ST-006
para no duplicar formularios (nombre de la sucursal vs `gym_profile.name`).

**Respuesta**: ☑ **Decidido: NO fusionar.** `gym_profile` queda como **extensión
ligada a `branch_id`** (cada sucursal física tiene su propio nombre, teléfono,
dirección y redes; ADR-0010 §10). No se fusiona con `branches`.

**N-04 — Edición de centro (ST-006 `PUT /centers`) y `gym_profile`**: como el
perfil vive a nivel sucursal, el `PUT /centers/{center_uuid}` edita **solo el
nombre/datos del centro**; el perfil de cada sucursal (incl. la principal) se edita
desde la vista de **Sucursales** (ST-015). Mientras ST-015 no exista, se permite
como **deuda temporal documentada** que el PUT de centro toque el `gym_profile` de
la sucursal principal, a retirar cuando llegue ST-015.

---

## Menores (registrar, no bloquean)

| # | Pregunta | Decisión / Estado |
| --- | --- | --- |
| M-01 | Nombre del "modo cliente". | ☑ **"Modo centro"**. |
| M-02 | Retención/limpieza de `audit_log`. | ☑ **Sin purga en esta fase** (crece indefinidamente); agendar política de retención (p. ej. 24 meses) a futuro. |
| M-03 | UX si un centro se desactiva con sesión impersonada activa. | ☑ El token **muere en el siguiente request** (el filtro valida centro activo); UX: **redirigir a login** con mensaje "centro desactivado". Confirmar el copy exacto. |
| M-04 | Zona horaria de `OPERATING_HOURS`. | ☑ **Cada centro configura la suya** (no hora del servidor); necesario para cadenas multi-ciudad. |
| M-05 | Almacenamiento de `OPERATING_HOURS` (ST-012). | ☑ **Estructura propia por centro** (tabla de horario por centro o columna `value`/JSON); `gym_config(name,type,is_enabled)` no basta. Definir el formato exacto al implementar ST-012. |

---

## Hallazgos nuevos (revisión de código + huecos entre historias, ST-001…ST-016)

Detectados al cotejar las stories contra la rama `Center-feature-branch`
(2026-10-21). N-01 y N-04 ya quedaron registrados arriba (en P-12 y P-10
respectivamente).

### N-02 — Tipo de `audit_log.center_id` no coincide con `centers.id` (FK)

**Hallazgo**: la migración `V202403121691__create_audit_log_table.sql` define
`center_id BIGINT` con FK a `centers(id)`, pero ADR-0002 define `centers.id` como
`INT UNSIGNED`. Un FK con tipo distinto al PK referenciado falla o degrada el índice
en InnoDB.

**Respuesta**: ☑ **Corregir**: `audit_log.center_id` → `INT UNSIGNED NULL`.
**Acción**: revisar además que las demás FK nuevas (`users.center_id` y las de
ST-004) usen `INT UNSIGNED` consistente con `centers.id`.

### N-03 — Numeración/orden de migraciones Flyway

**Hallazgo**: las migraciones multi-tenant usan prefijos `V2024031216xx` conviviendo
con otras más recientes. El riesgo real no es el prefijo sino que un backfill corra
antes de que exista la columna.

**Respuesta**: ☑ **Mantener orden monotónico y verificar en entorno limpio** que
`flyway migrate` corre en orden y que ninguna migración de `center_id` asume datos
que aún no existen. No renombrar migraciones ya aplicadas en algún entorno.

### N-05 — Falta ticket "Vista de auditoría" en ST-007

**Hallazgo**: ST-007 pide como criterio una "Sección de auditoría: tabla paginada de
`audit_log` con filtros", pero entre sus subtickets (portal, crear, catálogo, editar,
desactivar) no existe uno para la vista de auditoría.

**Respuesta**: ☑ **Crear un ticket propio** "ST-007 — Vista auditoría (audit_log)"
con tabla paginada y filtros (centro, actor, acción). Depende de ST-003.

### N-06 — "Entrar al centro" (impersonación) en ST-007 vs ST-009

**Hallazgo**: ST-007 lista "Acción Entrar al centro" como criterio, pero la
impersonación es ST-009 (ticket aparte).

**Respuesta**: ☑ **Fuera de alcance de ST-007**: en ST-007 solo queda el botón
(placeholder/deshabilitado); la lógica de impersonación (token, banner, auditoría)
se implementa en **ST-009**. Evita doble implementación.

### N-07 — Conteos de socios/usuarios en `GET /centers`

**Hallazgo**: ST-006 pide conteos de socios y usuarios por centro, sin definir si se
calculan en vivo o cacheados.

**Respuesta**: ☑ **Cálculo en vivo** (subquery/count agregado) por ahora; con pocas
decenas de centros es trivial. Nota: si crece a cientos, mover a columnas
materializadas o vista. Decisión reversible.

### N-08 — `articles.stock` tras `branch_stock` (ST-016)

**Hallazgo**: ST-016 deja abierto si `articles.stock` se elimina o queda como cache.

**Respuesta**: ☑ **Eliminar `articles.stock` del dominio**: `branch_stock` será la
única fuente de verdad del inventario (preferencia de la propia ST-016 y ADR-0010).
Se ejecuta al implementar ST-016.

### N-09 — Secreto JWT hardcodeado en `TokenProvider` (ST-010)

**Hallazgo**: ST-010 menciona un fallback de secreto hardcodeado y lo marca como
"mejora no bloqueante".

**Respuesta**: ☑ **Cerrarlo ahora, no diferir** (seguridad, G-seguridad): mover el
secreto a variable de entorno/configuración. **Acción**: pasarlo a criterio de
aceptación de **ST-010** (dejar de ser opcional).

### N-10 — Sucursal para `ADMIN`/`CENTER_ADMIN` sin `branch_uuid` en el token

**Hallazgo**: ST-010/ST-016 dicen que `ADMIN`/`CENTER_ADMIN` sin sucursal eligen
sucursal en la vista; falta el comportamiento cuando no la seleccionan.

**Respuesta**: ☑ **El front obliga a seleccionar sucursal** cuando el registro la
requiere (apertura de turno, check-in, venta); **el backend valida** que la sucursal
pertenezca al centro del token. Si no se selecciona, la operación se **rechaza** (no
se asume una sucursal por defecto, para no contaminar la contabilidad — G4/G5).
**Nota**: con P-13 (Opción 2), un `ADMIN` con `branch_id` asignado opera
directamente su sucursal sin necesidad de seleccionarla.

---

## Respuestas resueltas (histórico de esta lista)

| # | Pregunta | Respuesta | Dónde quedó |
| --- | --- | --- | --- |
| C-02 | ¿Filtro por defecto en vista de usuarios superadmin? | Sin filtro por defecto (respuesta posterior del doc base prevalece sobre "mostrar superadministradores por default") | ST-008 |
| P-01 | ¿`users.username` es el correo? | **Sí**: `username` ES el correo electrónico. Se valida formato email al crear usuarios por UI/API; los usuarios internos del sistema (`CHECKIN_*`, admin inicial) son excepción documentada sin validación de formato. Correo único global se mantiene. | ADR-0003, ST-002, ST-006, ST-008 |
| P-03 | ¿Cómo nace el primer `SUPERADMIN`? | `DefaultAdminInitializer` (mismo mecanismo del admin actual, hoy con `DEFAULT_ADMIN_PASSWORD_HASH`) crea el `SUPERADMIN` al arrancar con credenciales por variables de entorno. El script de migración NO lo crea. | ST-002, ST-014 |
| P-04 | ¿Usuario quiosco por centro nuevo? | **Sí, uno por centro**: el alta de centro crea un usuario de recepción (rol `REGISTRATION`) con username derivado del nombre del centro, único global (p. ej. `CHECKIN_<slug>`); es usuario interno (exento de formato correo). Replica el patrón de `CHECKIN_GYM`. | ST-006 |
| P-06 | ¿Renombrar rol `USER` → `STAFF`? | **Sí, renombrar** (el doc base lo pide: "Staff (cambiar en código)"). Cambio en enum backend + migración de datos (`UPDATE users`) + ajustes de frontend. | ADR-0003, ST-002, ST-008, ST-011 |
| P-07 | ¿Planes del SaaS en esta fase? | **Diferido formalmente**: sin tablas `plans`/`center_plans`, sin asignación de plan al crear centro, sin enforcement. Los centros nacen con todas las funcionalidades. El requisito del doc base queda registrado para la fase posterior. | ADR-0009, ST-006 |
| P-11 | ¿Cómo se detecta "conexión remota" en turnos? | **Fuera de alcance de esta fase**. La aprobación se dispara solo por horario/desfase (`OPERATING_HOURS`); se quitó el disparador por conexión remota de ADR-0006. | ADR-0006 |
| S-01 | ¿Se diseñan sucursales ahora? | **Sí**: se incorporaron al diseño (ya no son fase posterior) con requisito de **contabilidad aislada por sucursal**. Reconciliado con la regla del doc base ("financiero no ligado a sucursales"): el dinero lleva `branch_id` para reportes exactos, y las sucursales nunca se borran físicamente, así la historia sobrevive. | ADR-0010 |
| S-02 | ¿Socios: centro o sucursal? | **Nivel centro**: el socio se registra una vez y entra a cualquier sucursal de su centro; check-ins/ventas se marcan con la sucursal donde ocurrieron. | ADR-0010 |
| S-03 | ¿Staff y turnos: centro o sucursal? | **Staff por sucursal** (STAFF/REGISTRATION/quiosco requieren `branch_id`; ADMIN/CENTER_ADMIN abarcan el centro), **un turno de caja abierto por sucursal**, token con `center_uuid` + `branch_uuid`. | ADR-0010, ADR-0004 |
| S-04 | ¿Tarifas/planes/artículos compartidos? | **Catálogo a nivel centro** (precios únicos); **stock por sucursal** (nueva tabla `branch_stock`). Override de precios por sucursal = fase posterior. | ADR-0010 |
| S-05 | ¿Cómo sobrevive la contabilidad a la eliminación de una sucursal? | **Solo desactivación lógica**: no existe borrado físico de sucursales; toda FK financiera queda intacta. | ADR-0010 |
