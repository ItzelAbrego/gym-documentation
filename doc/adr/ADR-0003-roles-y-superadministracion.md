# ADR-0003: Roles, superadministración e impersonación con auditoría

**Estado**: Aceptada · **Fecha**: 2026-09-21


## Contexto

Los roles actuales del código son `ADMIN`, `USER`, `REGISTRATION` (`UserRole.java`;
el "Staff" del plan de origen es `USER`) y la jerarquía se expresa en
`User.getAuthorities()`: ADMIN hereda los authorities de USER y REGISTRATION. La
tabla `users` no tiene noción de centro. Para el modo SaaS se necesita: administración
del sistema (entre centros) separada de la operación de un centro, y un rol de
"usuario de facturación" renombrado.

## Decisión

### Modelo

1. **`users.center_id` nullable** (FK a `centers`): `NULL` = superadministrador. No se
   crea un centro "fantasma" para anclar a los superadmins. Existe además
   **`users.branch_id` nullable** (ADR-0010): obligatorio para `STAFF`/
   `REGISTRATION` (incl. quioscos), NULL para `ADMIN`/`CENTER_ADMIN` (ámbito de
   todo su centro) y siempre NULL para `SUPERADMIN`.
2. **Valores del enum `UserRole`**:
   - `SUPERADMIN` — administra el sistema: crea/desactiva centros, asigna planes,
     gestiona usuarios. Sus usuarios llevan `center_id = NULL` y no pueden ser
     editados entre sí.
   - `CENTER_ADMIN` — renombra al antiguo "Billing": usuario principal de un centro.
     Puede crear usuarios y cambiar roles dentro de su centro. Puede haber varios por
     centro; el cambio de rol a `CENTER_ADMIN` solo lo concede un superadmin.
   - `STAFF` — **renombre de `USER`** (decisión P-06: el doc base lo pide como
     "Staff (cambiar en código)"). Se renombra el valor del enum y se migran los
     datos existentes (`UPDATE users SET user_role = 'STAFF' WHERE user_role = 'USER'`),
     junto con los mapeos del frontend.
   - `ADMIN`, `REGISTRATION` — permanecen.
3. **Jerarquía de authorities** (`User.getAuthorities()` a actualizar):
   `SUPERADMIN` → todo; `CENTER_ADMIN` → `ADMIN` + `STAFF` + `REGISTRATION`;
   `ADMIN` → `STAFF` + `REGISTRATION`; etc. Superadmin **no** actúa como
   `CENTER_ADMIN` permanente: son cuentas separadas para que sus acciones sean
   auditables.
4. **`username` ES el correo electrónico, único global** (decisión P-01; se
   mantiene el UNIQUE de `username`): cada persona es un usuario global que
   pertenece a 0 o 1 centros. El login del doc base ("usa su correo") queda
   cumplido sin columna nueva. Reglas:
   - Todo usuario creado por UI/API debe pasar validación de formato email en
     backend (no solo frontend).
   - **Excepción documentada**: los usuarios internos del sistema no son correos
     y están exentos de esa validación: `CHECKIN_GYM` y los quioscos
     `CHECKIN_<centro>` por centro (P-04, ST-006) y el `SUPERADMIN` inicial (abajo).
5. **Creación del primer `SUPERADMIN`** (decisión P-03): el inicializador de
   arranque actual (`DefaultAdminInitializer`, mismo mecanismo que crea hoy al
   admin con `DEFAULT_ADMIN_PASSWORD_HASH`) crea el `SUPERADMIN` con credenciales
   por variables de entorno. No lo crea el script de migración (ST-014).

### Acceso del superadmin a un centro (impersonación)

- El superadmin entra a la interfaz de un centro mediante **impersonación**: sesión
  con rol `CENTER_ADMIN` temporal ligado a ese centro.
- La UI muestra un **banner visible** de modo superadmin con opción de regresar al
  panel de superadministración.
- Cada entrada, acción y salida se registra en `audit_log` (ST-003): superadmin,
  centro, acción, timestamp.
- Se emite un token nuevo con claim de centro impersonado (ADR-0004); al salir se
  re-emite el token sin centro.

### Log de auditoría

Tabla `audit_log`: `id`, `actor_username`, `center_id` (nullable), `action`,
`target` (JSON/texto), `created_at`. Escrita por el servicio de auditoría en:
impersonación (entrada/salida), acciones de superadmin sobre centros y usuarios, y
operaciones durante una sesión impersonada.

## Consecuencias

- `AuthService.signUp` y la vista Usuarios del frontend deben validar el rol y el
  centro destino según quién crea el usuario.
- El frontend (guards y menú, ver ST-011) debe conocer `SUPERADMIN` y `CENTER_ADMIN`;
  el `AuthGuard` actual solo compara `userRole === 'ADMIN'` (`auth.guard.ts:23`) y el
  menú filtra por `ADMIN`/`REGISTRATION`/resto (`menu-items.ts:75-91`).
- Los usuarios con rol `ADMIN` existentes no cambian; solo se agregan roles nuevos.
- La vista de superadmin muestra a todos los usuarios del sistema con filtros
  (rol, nombre, centro); la vista de centro solo ve a los usuarios de su centro.

## Alternativas consideradas

- **Centro reservado del sistema**: evita NULLs pero ensucia el catálogo de centros.
- **Tabla puente users↔centers**: permitiría multi-centro por usuario, pero
  contradice "un usuario = un centro" y agrega complejidad innecesaria ahora.
- **Solo lectura para superadmin en centros**: limita la ayuda remota/depuración que
  exige el plan de origen.
