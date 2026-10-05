---
id: ST-002
tipo: story
titulo: users.center_id nullable y rol CENTER_ADMIN
grupo: Principal
estado: pendiente
depende_de:
  - ST-001
adrs:
  - ADR-0003
---

# ST-002 — `users.center_id` nullable y rol `CENTER_ADMIN`

**Grupo**: Principal · **Depende de**: ST-001 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** operador del sistema **quiero** que cada usuario pertenezca a 0 o 1 centros
y existan los roles de superadministrador y administrador de centro **para** separar
la administración del sistema de la operación de cada centro.

## Criterios de aceptación

- [ ] Migración Flyway: `users.center_id INT NULL` + FK a `centers` + índice.
- [ ] `UserRole` agrega `SUPERADMIN` y `CENTER_ADMIN` **y renombra `USER` →
      `STAFF`** (`entity/UserRole.java`), con migración de datos
      (`UPDATE users SET user_role = 'STAFF' WHERE user_role = 'USER'`) — decisión P-06.
- [ ] `User.getAuthorities()` actualizado: `SUPERADMIN` → todo;
      `CENTER_ADMIN` → `ADMIN`+`STAFF`+`REGISTRATION` (jerarquía de ADR-0003).
- [ ] Entidad `User` con relación a `Center` (nullable).
- [ ] `username` validado como formato de correo electrónico en backend al crear
      usuarios por UI/API (decisión P-01). Exentos: usuarios internos del sistema
      (`CHECKIN_GYM`, quioscos `CHECKIN_<centro>`, admin inicial).
- [ ] `AuthService.signUp` valida: solo superadmin crea superadmins; un
      `CENTER_ADMIN` crea usuarios solo de su centro.
- [ ] El usuario `CHECKIN_GYM` y el admin inicial creado al arrancar quedan ligados
      al centro de la instalación (inicialización actualizada).
- [ ] `DefaultAdminInitializer` crea el primer `SUPERADMIN` al arrancar con
      credenciales por variables de entorno (decisión P-03; mismo mecanismo del
      admin actual con `DEFAULT_ADMIN_PASSWORD_HASH`).
- [ ] Ningún endpoint existente rompe: los usuarios sin centro son superadmin, los
      demás llevan su centro.

## Notas técnicas

- `User.getAuthorities()` hoy hereda authorities: `ADMIN` incluye `USER` y
  `REGISTRATION` (`User.java:53-65`) — extender la misma mecánica (con `STAFF`).
- El endpoint `/api/v1/auth/signup` (POST) es quien crea usuarios
  (`AuthController.java:43-47`); agregar la regla de centro/rol ahí y en
  `AuthService`.
