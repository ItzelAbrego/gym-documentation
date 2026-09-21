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

**Respuesta**: ☐ Abierta (dejada así a petición; recomendación: no bloquea).

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

**Respuesta**: ☐ Pendiente.

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

**Respuesta**: ☐ Abierta (documentar ambos casos; recomendación: Opción A).

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

**Respuesta**: ☐ Pendiente (se puede decidir junto con la fase de planes).

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

**Respuesta**: ☐ Pendiente.

---

### P-10 — `gym_profile`: ¿fusionar con `centers` o extensión?

**Doc base** ("Nota sobre gym_profile"): *"candidata a fundirse con la tabla
centers… o a quedar como su extensión ligada por `center_id`. Se decide al
implementar."*
[ADR-0002](./adr/ADR-0002-identificacion-de-centros.md) eligió extensión pero lo
dejó como "opción a evaluar al implementar; no es bloqueante".

**Estado**: sigue abierto deliberadamente. Decidir antes de implementar ST-006
para no duplicar formularios (nombre del centro vs `gym_profile.name`).

**Respuesta**: ☐ Pendiente.

---

## Menores (registrar, no bloquean)

| # | Pregunta | Estado |
| --- | --- | --- |
| M-01 | Nombre del "modo cliente" (doc base: "nombre por definir"). Propuesta: **Modo centro**. | ☐ |
| M-02 | Retención/limpieza de `audit_log` (¿se depura o crece indefinidamente?) | ☐ |
| M-03 | Si un centro se desactiva **mientras** hay una sesión impersonada activa, el token muere (filtro valida centro activo); confirmar UX esperada. | ☐ |
| M-04 | Zona horaria para `OPERATING_HOURS`: ¿cada centro configura la suya o se asume hora local del servidor? | ☐ |
| M-05 | `gym_config(name, type, is_enabled)` no puede guardar horarios + desfase para `OPERATING_HOURS` (ST-012): ¿columna `value`/JSON, o tabla de horario por centro? | ☐ |

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
