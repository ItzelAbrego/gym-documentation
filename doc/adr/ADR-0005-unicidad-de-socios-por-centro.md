# ADR-0005: Unicidad de teléfonos y correos de socios por centro

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

Hoy un socio es único por teléfono y por correo **a nivel global**:

- `members.cell_phone` UNIQUE (`schema.sql:81`; `Member.java:49`)
- `members.email` UNIQUE (`schema.sql:67`; `Member.java:52`)
- `MemberRepository.findByCellPhone(String)` / `findByEmail(String)` (sin centro)
- `MemberService.validateDuplicateCellPhoneMember` /
  `validateDuplicateEmailMember` (`MemberService.java:175-195`)
- `checkMemberByCellPhone` para el check-in (`MemberService.java:225-237`)

El plan SaaS exige que el mismo teléfono (persona) pueda existir en varios centros:
la identidad del socio es **local al centro**, no global.

## Decisión

> **RECONCILIACIÓN (2026-11-11, decisión N-11)**: las unique keys que esta ADR
> decidió **ya no son las implementadas**. `V202403121703` (ST-005) las creó tal
> como dice el punto 1, y `V202403121706` (ST-016) las reemplazó tres
> migraciones después:
>
> ```sql
> DROP INDEX uq_members_center_cell_phone,
> DROP INDEX uq_members_center_email,
> ADD UNIQUE KEY uq_members_center_branch_cell_phone (center_id, branch_id, cell_phone),
> ADD UNIQUE KEY uq_members_center_branch_email     (center_id, branch_id, email);
> ```
>
> El socio pasó a ser **de la sucursal**, no del centro. Lo que esta ADR pedía —
> que la misma persona pueda existir en varios centros — sigue cumpliéndose, y
> además ahora puede existir varias veces dentro de un centro, una por sucursal.
>
> Lo que **sigue vigente** de este documento: el punto 3 (`created_by` y los
> `username` de auditoría no se duplican), el punto 4 (herencia de
> `member_fingerprint_templates` y `member_status`), y el razonamiento de por qué
> la unicidad global original era inviable.
>
> Lo que **hay que corregir** en el punto 2: la búsqueda interna ya no alcanza
> con teléfono + centro. `findByCenterIdAndCellPhone` devolvería varias filas en
> un centro con dos sucursales. Tiene que pasar a teléfono + centro + sucursal, y
> el check-in resolverlo con el `branch_uuid` del token (ADR-0004 + regla 8 de
> ADR-0010). **Esto es un cambio de código pendiente**, no sólo de documento.

1. **Unique keys compuestas por centro**:
   - `UNIQUE (center_id, cell_phone)`
   - `UNIQUE (center_id, email)` — correo de socio único por centro (opcional; se
     mantiene por simetría con el teléfono; el correo del socio no es credencial de
     login, esa función es de `users.username`).
2. **Búsqueda interna siempre por teléfono + centro**:
   `findByCenterIdAndCellPhone(centerId, cellPhone)`. El check-in
   (`CheckInService.checkInCheckOut` → `checkMemberByCellPhone`) busca con el centro
   del token (ADR-0004) y, si no existe, registra en `invalid_check_ins` con centro.
3. **`created_by` y campos `username` de auditoría** se mantienen (el usuario es
   global y único); no se duplican por centro.
4. `member_fingerprint_templates` y `member_status` se heredan del miembro vía su
   `member_id`; llevan `center_id` por conveniencia de consultas (ADR-0001).

## Consecuencias

- La migración (ADR-0007) debe eliminar los UNIQUE globales de `members` antes de
  crear los compuestos, para no chocar con teléfonos repetidos entre centros futuros
  (con un solo centro migrado no hay choque, pero el esquema debe quedar listo).
- `MemberService` deja de validar duplicados globales y pasa a validar por centro.
- El formulario de socio ya no debe advertir "teléfono ya registrado" sin filtrar por
  centro.
- Los `members` internos semilla (`'1111111111'` = "Público en General",
  `'WALK_IN'` = "Visita público general", `schema.sql:531-537`) deben existir por
  centro: la inicialización de un centro nuevo (ST-006/ST-014) los crea.

## Alternativas consideradas

- **Mantener unicidad global y "compartir" socios entre centros**: implica un
  entidad socio global con membresías por centro; restructura todo el dominio
  (membresías, suscripciones, cortesías, check-ins apuntarían al socio global) y
  complica la migración — se descarta para esta fase.
- **Solo teléfono por centro, correo global único**: inconsistente; el correo del
  socio no tiene rol de login, no necesita unicidad global.
