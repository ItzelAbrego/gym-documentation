# ST-012 — Aprobación de turnos fuera de horario de instalaciones

**Grupo**: Adaptación · **Depende de**: ST-002, ST-013 · **ADRs**: [ADR-0006](../adr/ADR-0006-aprobacion-de-turnos-fuera-de-instalaciones.md)

## Historia de usuario

**Como** administrador de centro **quiero** recibir solicitudes de aprobación
cuando un responsable abre o cierra turno fuera del horario del gym **para**
controlar las excepciones sin bloquear la operación.

## Criterios de aceptación

- [ ] Nueva configuración `OPERATING_HOURS` en `gym_config` (por centro): día(s) y
      horario de atención + desfase tolerado en minutos (threshold).
- [ ] Al cerrar turno fuera de horario + desfase (`WorkShiftService`
      `closeWorkShift`, hoy exige revisor con `UserRole.ADMIN` en
      `WorkShiftService.java:89-91`): el turno queda en estado
      `CLOSED_PENDING_APPROVAL` y se genera solicitud pendiente.
- [ ] Análogo al abrir fuera de horario: `OPEN_PENDING_APPROVAL`.
- [ ] Los turnos pendientes NO bloquean: check-ins, ventas y débitos siguen
      operando (decisión: sin regla dura de 8h, todo pasa por aprobación).
- [ ] Cola de aprobaciones visible para `CENTER_ADMIN` y `ADMIN`: aprobar o
      rechazar; al aprobar el turno pasa a cerrado/abierto definitivo y se
      asigna `closing_reviewer_admin_user`/`opening_reviewer_admin_user`
      (`schema.sql:128-137`) al aprobador.
- [ ] Si no se aprueba a tiempo, la operación continúa; el pendiente queda como
      registro para reporte (se decide notificación fuera de esta fase).

## Notas técnicas

- Reutiliza el patrón existente de aprobación por revisor
  (`opening_reviewer_admin_user`/`closing_reviewer_admin_user` en `WorkShift`) y
  el precedente de `debit_transactions.admin_user_cancellation_approval`
  (`schema.sql:150-164`).
- `getWorkShiftsByFilters` (`WorkShiftService`) distingue por rol; agregar el
  estado pendiente a los filtros y la cola.
- El centro del turno viene del token (ST-010/ST-013); la comparación con
  `OPERATING_HOURS` es por centro.
