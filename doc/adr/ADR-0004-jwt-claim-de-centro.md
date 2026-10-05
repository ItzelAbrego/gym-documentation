# ADR-0004: JWT con claim de centro — el cliente no envía el centro

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

La autenticación actual (verificado en código): `AuthController.signIn`
(`controller/AuthController.java:64-87`) retorna `accessToken`, `username`, `userRole`;
el token lo genera `TokenProvider` (`service/TokenProvider.java`) con
`Algorithm.HMAC256`, `subject = username` y un único claim `username`, expiración de
4 horas. El frontend guarda `token`, `username` y `userRole` en `localStorage`
(`gym-web/.../auth.service.ts:28-45`) y manda el header `Authorization: Bearer` por
petición. Un filtro de Spring Security valida el token y pobla el
`SecurityContextHolder` (los servicios leen al usuario con
`SecurityContextHolder.getContext().getAuthentication()` — p. ej.
`WorkShiftService.java:36,70,106`).

En modo SaaS, cada petición debe operar sobre el centro del usuario. Había dos
caminos: que el frontend guarde y envíe el UUID del centro en cada petición, o que el
backend lo derive del token.

## Decisión

**El centro viaja dentro del JWT como claim**, emitido al iniciar sesión, y el filtro
de autenticación lo extrae y lo pone a disposición de los endpoints.

1. `TokenProvider.generateAccessToken(User)` agrega los claims:
   - `center_uuid`: `center_uuid` del usuario (NULL para superadmins).
   - `branch_uuid`: `branch_uuid` del usuario, para staff asignado a una sucursal
     (NULL para `ADMIN`/`CENTER_ADMIN`/`SUPERADMIN` — ver
     [ADR-0010](ADR-0010-sucursales-contabilidad-aislada.md)).
   - `user_role`: nombre del rol (deja de depender de una respuesta separada).
2. El filtro que valida el token resuelve el centro una vez (por `center_uuid`) y lo
   expone como atributo de la petición / argumento de controller / servicio (los
   servicios ya obtienen el usuario del `SecurityContextHolder`; el centro sigue el
   mismo patrón).
3. El **frontend no envía el centro** en peticiones: fuente única de verdad, no
   manipulable desde el cliente. Lo único que guarda es el propio token y datos para
   el enrutado de la UI.
4. En **impersonación** (ADR-0003) se emite un token nuevo con el claim
   `center_uuid` del centro impersonado y `impersonated_by = username` del superadmin;
   al terminar se re-emite el token original.
5. Los endpoints de superadministrador ignoran/rechazan `center_uuid` (esperan token
   sin centro).

## Consecuencias

- Cambiar de rol o centro implica re-emitir el token (nuevo login o impersonación).
- El `SignInDto` de respuesta puede seguir retornando `username`/`userRole` para la
  UI, pero el centro ya no es algo que el cliente gestione.
- La expiración de 4h y el logout-timer del frontend (4h, `auth.service.ts:125-136`)
  siguen funcionando sin cambios.
- Riesgo: reclamar el centro en cada petición a partir del token acopla la validez
  del centro a la vigencia del token — deseado: si desactivan al usuario o cambian su
  centro, el token viejo muere en ≤4h.

## Alternativas consideradas

- **Frontend envía `center_uuid` en cada petición** (header/param): más flexible si
  un usuario pudiera pertenece a varios centros, pero el centro sería dato del
  cliente, manipulable, y duplicaría la fuente de verdad.
- **Resolver el centro en cada petición desde la BD (`users.center_id`)**: posible,
  pero agrega una consulta por petición y separa la identidad de la sesión de su
  contexto; el claim además permite auditoría puntual (impersonación) sin mutar al
  usuario.
