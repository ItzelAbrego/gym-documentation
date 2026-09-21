# ST-013 — Scoping multi-tenant de endpoints y servicios

**Grupo**: Adaptación · **Depende de**: ST-004, ST-010 · **ADRs**: [ADR-0001](../adr/ADR-0001-arquitectura-multi-tenant.md), [ADR-0004](../adr/ADR-0004-jwt-claim-de-centro.md)

## Historia de usuario

**Como** centro **quiero** que ningún endpoint me muestre ni modifique datos de
otro centro **para** garantizar aislamiento total en la API.

## Criterios de aceptación

- [ ] Cada controller/servicio existente toma el centro del claim del token y lo
      pasa a los repositorios (los métodos globales de ST-004 ya aceptan centro):
      - `MemberController` `/api/member` y `MemberService` (listados, filtros,
        save/update, check-in por teléfono).
      - `WorkShiftController` `/api/work-shift` (abrir/cerrar/listar; el usuario
        del turno sale del `SecurityContextHolder` como hoy).
      - `CheckInService` (check-ins válidos e `invalid_check_ins`).
      - `GymConfigService` (`findAll`/`findByType` globales hoy → por centro).
      - Tarifas/rates, cortesías, suscripciones, débitos, ventas, inventario,
        compras, artículos, reportes y calendario.
- [ ] Los jobs del `scheduler` (expiración de suscripciones/tarifas/cortesías)
      procesan todos los centros: iteran centros activos y aplican la misma
      lógica por centro.
- [ ] El superadmin sin impersonación no puede ejecutar endpoints operativos
      (solo los de superadmin de ST-006); para operar debe impersonar (ST-009).
- [ ] El filtro valida que el centro del token esté activo y exista en cada
      request (tokens de centros desactivados se rechazan).
- [ ] Regresión: todos los flujos actuales del gym original funcionan igual con
      su centro (incluye check-in con socio semilla y registro con
      `CHECKIN_GYM`).

## Notas técnicas

- `MemberService` lee el usuario de `SecurityContextHolder` en varios puntos
  (p. ej. en `saveMember`); con impersonación el usuario efectivo es el
  superadmin impersonado — se conserva la trazabilidad vía `audit_log` y el
  claim `impersonated_by`.
- `WorkShiftRepository.findOpenWorkShift()` global (`WorkShiftRepository.java:66-67`)
  debe resolverse por centro o romperá la apertura de turnos entre centros.
- Añadir un test de aislamiento mínimo por endpoint clave (smoke: usuario de
  centro A no ve datos de centro B) — mismo nivel de pruebas que hoy tiene el
  proyecto.
