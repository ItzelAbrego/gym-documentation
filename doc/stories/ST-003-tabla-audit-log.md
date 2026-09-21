# ST-003 — Tabla `audit_log` y servicio de auditoría

**Grupo**: Principal · **Depende de**: ST-001 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** superadministrador **quiero** un registro de auditoría de acciones
sensibles (impersonación, gestión de centros y usuarios) **para** poder auditar quién
hizo qué, cuándo y en qué centro.

## Criterios de aceptación

- [ ] Migración Flyway crea `audit_log`: `id`, `actor_username`, `center_id`
      (nullable), `action` (enum: `IMPERSONATION_START`, `IMPERSONATION_END`,
      `CENTER_CREATED`, `CENTER_DISABLED`, `USER_CREATED`, `USER_ROLE_CHANGED`,
      etc.), `target` (texto/JSON), `created_at`.
- [ ] Entidad `AuditLog` + `AuditLogRepository` + `AuditService.record(...)`.
- [ ] El servicio escribe con el usuario del `SecurityContextHolder` (mismo patrón
      que `WorkShiftService`).
- [ ] Impersonación registra entrada y salida (se conecta en ST-009).
- [ ] La vista de superadmin puede listar el log (endpoint paginado con filtros por
      centro, actor y acción).

## Notas técnicas

- No auditar todo el CRUD operativo: solo acciones de administración del sistema y
  sesiones impersonadas. El log operativo por centro ya existe de facto en las
  tablas `*_history`.
