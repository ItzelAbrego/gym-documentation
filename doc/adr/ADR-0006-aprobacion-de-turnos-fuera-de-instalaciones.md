# ADR-0006: Aprobación de apertura/cierre de turnos con desfase

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

El plan de origen pide evitar modificaciones malintencionadas de turnos por usuarios
fuera de las instalaciones del centro. Se plantearon dos mecanismos: estado especial
automático tras 8 horas abiertas, o solicitud de aprobación al administrador al
abrir/cerrar. (La detección de conexión remota se descartó para esta fase — P-11;
el control queda por horario y desfase.)

El código ya tiene un patrón de aprobación por revisor que se puede extender:

- `WorkShift.openingReviewerAdminUser` / `closingReviewerAdminUser`
  (`WorkShift.java:42-46`; `schema.sql:128-137`).
- `WorkShiftService.openWorkShift` y `closeWorkShift` exigen que el revisor exista y
  tenga rol `ADMIN` (`WorkShiftService.java:47-49, 89-91`).
- `debit_transactions.admin_user_cancellation_approval`
  (`DebitTransaction.java:51-52`) — cancelación con aprobación de admin.
- `cancellations` guarda quién canceló (`schema.sql:285-294`).

## Decisión

**Aprobación explícita del `CENTER_ADMIN` al abrir o cerrar un turno con desfase.**
No se impone una regla dura de 8 horas.

Reglas:

1. Al **abrir** un turno, si la hora está fuera del horario de operación del centro
   (configurable en `gym_config`, tipo nuevo `OPERATING_HOURS`), la apertura queda en
   estado `PENDING_APPROVAL` y se notifica al `CENTER_ADMIN` (y a los `ADMIN` del
   centro, p. ej. en pantalla de Turnos).
2. Al **cerrar** un turno, si el desfase respecto a la apertura excede un umbral del
   centro, el cierre queda `PENDING_APPROVAL` y requiere aprobación del
   `CENTER_ADMIN`. (El criterio "desde una conexión remota" queda **fuera de
   alcance** de esta fase — decisión P-11: no hay mecanismo definido para detectar
   conexión remota).
3. La aprobación usa el patrón existente: se llena `opening_reviewer_admin_user` /
   `closing_reviewer_admin_user` con el usuario que aprueba (hoy lo llena el formulario
   con huella/admin; pasa a ser el `CENTER_ADMIN` que aprueba en la cola).
4. **En revisión (C-01)**: mientras un turno esté `PENDING_APPROVAL`… — hay
   contradicción entre esta regla (no se registran transacciones nuevas contra él)
   y ST-012/diagrama 4 (la operación continúa). Recomendación: **no bloquear**
   (la aprobación es control posterior, no candado). Se corrige esta regla al
   cerrar C-01 en `preguntas-y-respuestas.md`.
5. Las columnas de estado nuevas (`pending_approval` / `approved` / `rejected` +
   timestamps) viven en `work_shifts` o en una tabla `work_shift_approvals` ligada; se
   decide en implementación, prefiriendo columnas en `work_shifts` para no duplicar el
   flujo de revisores ya existente.

## Consecuencias

- El staff puede seguir trabajando con horarios atípicos sin bloqueos automáticos
  sorpresivos; la fricción se concentra donde hay riesgo (desfase/remoto).
- El frontend de Turnos (vista existente) gana una cola de aprobaciones visible solo
  para `CENTER_ADMIN`/`ADMIN` del centro.
- El umbral de desfase y el horario del centro son configuración del centro
  (`gym_config`), no código duro.
- El "estado especial tras 8h" queda descartado: regla rígida, más fricción y no
  cubre el caso de conexión remota con turno de menos de 8h.

## Alternativas consideradas

- **Estado automático tras 8h**: determinista pero rígido; no cubre remoto con turnos
  cortos y bloquea al staff legítimo.
- **Ambos (8h + aprobación)**: máxima restricción, fricción doble sin valor claro.
