# ST-006 — API de superadministración de centros

**Grupo**: Superadmin · **Depende de**: ST-001, ST-002, ST-003, ST-005 · **ADRs**: [ADR-0002](../adr/ADR-0002-identificacion-de-centros.md), [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** superadministrador **quiero** crear, listar, editar y desactivar centros
desde la API **para** dar de alta nuevos clientes FitRoom sin tocar la base de datos.

## Criterios de aceptación

- [ ] Endpoints bajo `/api/v1/centers` accesibles solo con rol `SUPERADMIN`
      (rechaza cualquier token con `center_uuid`, es decir, usuarios de centro).
- [ ] `POST /centers`: crea centro (nombre, datos de perfil) + obligatoriamente
      crea el usuario `CENTER_ADMIN` inicial (username = correo validado, nombre,
      password — decisión P-01) en la misma transacción; crea también el **usuario
      quiosco** del centro (rol `REGISTRATION`, username único global derivado del
      nombre del centro, p. ej. `CHECKIN_<slug>`, exento de formato correo —
      decisión P-04); genera `center_uuid` v4; inserta socios semilla
      ("Público en General", "Visita") y configuraciones `gym_profile`/`gym_config`
      iniciales del centro; registra `CENTER_CREATED` en `audit_log`.
      **Sin asignación de plan** (planes diferidos — ADR-0009).
- [ ] `GET /centers`: lista paginada con búsqueda por nombre, filtro por `active`;
      incluye conteos útiles (socios, usuarios).
- [ ] `PUT /centers/{center_uuid}`: nombre y datos de perfil.
- [ ] `DELETE /centers/{center_uuid}`: desactivación lógica (`active = false`);
      el borrado físico es asíncrono/manual fuera de esta fase.
- [ ] Al desactivar: los tokens de usuarios del centro dejan de funcionar en el
      siguiente request (el filtro valida que el centro siga activo).

## Notas técnicas

- La creación de centro reutiliza la lógica de `AuthService.signUp`
  (`AuthController.java:43-47`) para el usuario admin, pero como `CENTER_ADMIN`
  ligado al nuevo centro.
- Los socios semilla (`schema.sql:541-547`) se convierten en plantillas del
  servicio de creación.
- El JWT del superadmin no lleva `center_uuid` (ST-010); este endpoint no
  requiere impersonación.
