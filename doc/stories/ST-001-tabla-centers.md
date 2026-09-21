# ST-001 — Tabla `centers` con id + UUID y su modelo

**Grupo**: Principal · **Depende de**: — · **ADRs**: [ADR-0001](../adr/ADR-0001-arquitectura-multi-tenant.md), [ADR-0002](../adr/ADR-0002-identificacion-de-centros.md)

## Historia de usuario

**Como** sistema FitRoom **quiero** una tabla de centros con identificador interno y
externo **para** poder operar como SaaS multi-tenant y exponer integraciones sin el
id numérico.

## Criterios de aceptación

- [ ] Migración Flyway crea `centers` (ver DDL en ADR-0002): `id` INT auto-increment
      PK, `center_uuid` BINARY(16) UNIQUE, `name`, `active`, timestamps.
- [ ] Entidad `Center` + `CenterRepository` (paquetes `entity`/`repository` de
      `com.fitroom.gym`).
- [ ] Generación de `center_uuid` v4 en el servicio de creación.
- [ ] Migración de datos de `schema.sql` no rompe la inicialización (proceso de
      arranque sigue funcionando: Flyway corre con `baseline-on-migrate: true`).
- [ ] Los endpoints de centro aceptan/devuelven `center_uuid`, nunca `id`.

## Notas técnicas

- La inicialización actual crea datos base al arrancar (comentario en
  `schema.sql:549-550` menciona `DefaultAdminInitializer`); su actualización para el
  centro por defecto se cubre en ST-002/ST-006.
- Ubicación de migraciones: `classpath:db/migration` y
  `classpath:com/fitroom/gym/db/migration` (`application.yml:25-27`), convención
  `VYYYYMMDDHHmm`.
