# ST-002 — `users.center_id` nullable y rol `CENTER_ADMIN`

**Grupo**: Principal · **Depende de**: ST-001 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** operador del sistema **quiero** que cada usuario pertenezca a 0 o 1 centros
y existan los roles de superadministrador y administrador de centro **para** separar
la administración del sistema de la operación de cada centro.

## Criterios de aceptación

- [ ] Migración Flyway: `users.center_id INT NULL` + FK a `centers` + índice.
- [ ] `UserRole` agrega `SUPERADMIN` y `CENTER_ADMIN` (`entity/UserRole.java`).
- [ ] `User.getAuthorities()` actualizado: `SUPERADMIN` → todo;
      `CENTER_ADMIN` → `ADMIN`+`USER`+`REGISTRATION` (jerarquía de ADR-0003).
- [ ] Entidad `User` con relación a `Center` (nullable).
- [ ] `AuthService.signUp` valida: solo superadmin crea superadmins; un
      `CENTER_ADMIN` crea usuarios solo de su centro.
- [ ] El usuario `CHECKIN_GYM` y el admin inicial creado al arrancar quedan ligados
      al centro de la instalación (inicialización actualizada).
- [ ] Ningún endpoint existente rompe: los usuarios sin centro son superadmin, los
      demás llevan su centro.

## Notas técnicas

- `User.getAuthorities()` hoy hereda authorities: `ADMIN` incluye `USER` y
  `REGISTRATION` (`User.java:53-65`) — extender la misma mecánica.
- El endpoint `/api/v1/auth/signup` (POST) es quien crea usuarios
  (`AuthController.java:43-47`); agregar la regla de centro/rol ahí y en
  `AuthService`.
