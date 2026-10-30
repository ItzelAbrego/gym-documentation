# ADR-0002: Identidad de centros — id numérico interno + UUID externo

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

La nueva tabla de centros necesita un identificador primario. Se pide que las
integraciones externas no expongan el ID numérico interno, pero también se necesita
indexado y joins baratos entre las ~35 tablas que llevarán `center_id` (ADR-0001).

## Decisión

La tabla `centers` tendrá **doble identificador**:

```sql
CREATE TABLE centers (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    center_uuid  BINARY(16)   NOT NULL,
    name         VARCHAR(255) NOT NULL,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_centers_uuid (center_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

> **Reconciliación con el código (2026-10-21, decisión N-02)**: la implementación
> real (`V202403121689__create_centers_table.sql` + entidad JPA `Center.id = Long`)
> usó **`BIGINT`**, no `INT UNSIGNED`. Este ADR se actualiza al tipo real: el tipo
> consistente del codebase para `centers.id` y todas sus FK entrantes
> (`users.center_id`, `audit_log.center_id`, y las de ST-004) es **`BIGINT`**. Una
> eventual migración a `INT UNSIGNED` sería un cambio coordinado de todas las tablas
> y queda fuera de alcance.

1. **`id` BIGINT auto-increment**: PK real y referencia interna (`center_id` en todas
   las FKs). Joins e índices compuestos baratos.
2. **`center_uuid` BINARY(16)**: el único identificador que sale del backend hacia
   clientes/APIs externas. Viaja en el JWT (ADR-0004) y se usa para buscar el centro.
3. **`active` BOOLEAN**: desactivación lógica; el borrado físico es un proceso
   asíncrono aparte (el catálogo de superadmin ofrece desactivar, no borrar en línea).

Además:

- `gym_profile` (perfil de la sucursal: nombre, teléfono, redes, dirección —
  verificado en `GymProfile.java`) se liga con `branch_id` (ADR-0010): cada
  sucursal física tiene identidad propia (dirección, nombre y teléfono distintos).
  Fusionarla con `branches` quedó como opción a evaluar al implementar; no es
  bloqueante.
- `gym_config` y `gym_config_history` reciben `center_id` (ver ADR-0008).

## Consecuencias

- Los endpoints de superadministrador devuelven y aceptan `center_uuid`, nunca `id`.
- El JWT lleva el `center_uuid` y el filtro resuelve el `id` numérico una vez por
  petición (o cachea la resolución).
- La migración (ADR-0007) genera el UUID para el centro histórico.

## Alternativas consideradas

- **Solo UUID**: simplifica, pero obliga a BINARY(16) en todas las FKs internas
  (indexado y joins más caros, índices secundarios más grandes).
- **Solo id numérico**: expone IDs a integraciones externas, que era lo que el plan
  quería evitar.
