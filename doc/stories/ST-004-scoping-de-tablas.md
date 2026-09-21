# ST-004 — Agregar `center_id` al resto de las tablas

**Grupo**: Principal · **Depende de**: ST-001 · **ADRs**: [ADR-0001](../adr/ADR-0001-arquitectura-multi-tenant.md)

## Historia de usuario

**Como** sistema multi-tenant **quiero** que toda fila de datos operativos pertenezca
a un centro **para** aislar la información de cada cliente.

## Criterios de aceptación

- [ ] Migración Flyway agrega `center_id INT NOT NULL` + FK + índice a las tablas del
      mapeo de ADR-0001 (excepto `users`, ya cubierto en ST-002, y los catálogos
      compartidos `states`, `cities`, `colonias`).
- [ ] `check_in`: se elimina el UNIQUE de `register_timestamp`
      (`CheckIn.java:38`, `schema.sql:207`) — colisionaría entre centros.
- [ ] `WorkShiftRepository.findOpenWorkShift()` pasa a `findOpenWorkShiftByCenterId(centerId)`
      (hoy asume un único turno abierto global — `WorkShiftRepository.java:66-67`).
- [ ] Entidades JPA actualizadas con relación `@ManyToOne` a `Center` (o campo
      `centerId` + columna).
- [ ] Los métodos de repositorio que hoy son globales aceptan el centro como filtro
      (la reescritura de llamadas es ST-013).
- [ ] Los jobs programados de `scheduler` (expiración de tarifas, suscripciones,
      cortesías) procesan filas de todos los centros sin romperse.

## Notas técnicas

- Estrategia para tablas de detalle/historial: heredar del padre
  (`check_out` → `check_in`, `subscription_history` → `subscriptions`) cuando el
  join ya es obligatorio; columna propia cuando se consulta directo. Decidir por
  tabla en la migración, documentado en la propia migración Flyway.
- `member_fingerprint_templates` y `member_status`: columna propia por conveniencia
  (se consultan en el check-in sin pasar por `members` a veces).
- Poblado de `center_id` en datos históricos lo hace el script de migración (ST-014);
  para desarrollo, la migración Flyway no necesita backfill (bases nuevas).
