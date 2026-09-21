# ST-014 — Script de migración de datos a multi-tenant

**Grupo**: Migración · **Depende de**: ST-001, ST-002, ST-003, ST-004, ST-005, ST-013 · **ADRs**: [ADR-0007](../adr/ADR-0007-migracion-de-datos.md)

## Historia de usuario

**Como** operador **quiero** un script one-shot que convierta la base actual del
gym en la base multi-tenant (un centro con todos los datos) **para** poner en
producción la versión SaaS sin perder datos.

## Criterios de aceptación

- [ ] Script Python one-shot que corre sobre un **backup restaurado** de la base
      actual (nunca sobre la base productiva original).
- [ ] Pasos: (1) verificar esquema con `center_id` aplicado (migraciones de
      ST-001…ST-005); (2) crear el centro: nombre desde `gym_profile`, `center_uuid`
      v4; (3) asignar `center_id` del nuevo centro a todas las tablas del mapeo
      ADR-0001, en orden de flujo de entidades (usuarios → socios → catálogos →
      transacciones → historiales); (4) insertar socios semilla ("Público en
      General" `'1111111111'`, "Visita" `'WALK_IN'`) ligados al centro y re-point
      sus referencias; (5) ligar usuarios no-superadmin al centro y crear el
      `CENTER_ADMIN` si no existe.
- [ ] Imprime conteos por tabla antes y después para verificación manual.
- [ ] Si falla: NO hay reanudación ni checkpoints — se restaura el backup y se
      reintenta desde cero (decisión registrada).
- [ ] Sin pruebas automatizadas: la verificación es manual con los conteos y un
      smoke de la app (login, check-in, apertura de turno).
- [ ] Al terminar, la base migrada levanta la app con un centro funcional
      (estado, configuraciones y datos de `gym_profile`/`gym_config` del centro).

## Notas técnicas

- Las llaves UNIQUE de `members` se vuelven compuestas `(center_id, cell_phone)` /
  `(center_id, email)`: con un solo centro la migración no choca con datos
  históricos.
- El script es un utilitario fuera del classpath de Flyway (Flyway solo corre las
  migraciones de esquema; el poblado es del script, como decidió el plan).
- Orden de entidades según ADR-0001: `centers` → `users` → `gym_profile`/`gym_config`
  → `members`/`member_status`/`member_fingerprint_templates` → `rates` y
  artículos → turnos → débitos → suscripciones/cortesías → check-in/out →
  ventas/compras → historiales y tablas de relación.
- El `SUPERADMIN` inicial **no** lo crea este script: lo crea
  `DefaultAdminInitializer` con credenciales por env al arrancar la app migrada
  (decisión P-03, ST-002). El script sí liga `CHECKIN_GYM` y el admin existente al
  centro migrado.
