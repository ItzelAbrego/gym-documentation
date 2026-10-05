---
id: ST-005
tipo: story
titulo: Unicidad de socios por centro
grupo: Principal
estado: pendiente
depende_de:
  - ST-001
  - ST-004
adrs:
  - ADR-0005
---

# ST-005 — Unicidad de socios por centro

**Grupo**: Principal · **Depende de**: ST-001, ST-004 · **ADRs**: [ADR-0005](../adr/ADR-0005-unicidad-de-socios-por-centro.md)

## Historia de usuario

**Como** cada centro **quiero** que los teléfonos y correos de socios sean únicos
dentro de mi centro (pero no necesariamente entre centros) **para** que dos gyms
diferentes puedan tener socios con el mismo contacto.

## Criterios de aceptación

- [ ] Migración Flyway: `members` cambia `UNIQUE(cell_phone)` → `UNIQUE(center_id, cell_phone)`
      y `UNIQUE(email)` → `UNIQUE(center_id, email)`
      (`schema.sql:81`, `schema.sql:67`).
- [ ] `MemberRepository`: nuevos métodos `findByCenterIdAndCellPhone` y
      `findByCenterIdAndEmail` (hoy `findByCellPhone`/`findByEmail` son globales).
- [ ] `MemberService.validateDuplicateCellPhoneMember` /
      `validateDuplicateEmailMember` (`MemberService.java:175-195`) validan dentro
      del centro del token.
- [ ] El lookup de check-in por teléfono (`checkMemberByCellPhone`) busca con el
      centro del token; el registro en `invalid_check_ins` lleva centro.
- [ ] Los socios semilla de cada centro (`'1111111111'` "Público en General" y
      `'WALK_IN'` "Visita") se crean por centro; las referencias FK en
      `checkin_*`, `subscriptions`, etc. apuntan al socio del centro propio.
- [ ] El script de migración (ST-014) no rompe con datos históricos: como al inicio
      hay un solo centro, las llaves compuestas son equivalentes a las globales.

## Notas técnicas

- Los socios semilla se documentan al final de `schema.sql` (~líneas 541-547): se
  convierten en plantillas de creación por centro (se ejecutan al crear un centro,
  ST-006) y quedan insertadas para el centro original en la migración (ST-014).
- El frontend no cambia en esta story: sigue enviando `cellphone` en el cuerpo; el
  centro viene del token (ST-010).
