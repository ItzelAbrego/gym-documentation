# ADR-0007: Migración de datos — script Python one-shot sobre backup

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

La base histórica (`fitroom`) es de un solo centro. La conversión a SaaS agrega
`center_id` a ~35 tablas, cambia unique keys de `members` (ADR-0005), quita el UNIQUE
global de `check_in.register_timestamp` y agrega `centers`/`audit_log`. Hay que
llevar los datos existentes a este esquema **una sola vez, por centro cliente**.

## Decisión

**Script Python one-shot** que corre contra un **backup restaurado** de la base
original; nunca contra la base en producción.

1. **Entrada**: dump SQL de la base original restaurado en una base de trabajo con el
   esquema nuevo ya aplicado (Flyway corre primero: crea `centers`, agrega
   `center_id`, ajusta unique keys).
2. **Pasos del script**:
   1. Crea el centro: toma el nombre de `gym_profile` de la base original, genera
      `center_uuid` (v4) y lo inserta en `centers`.
   2. Crea la **sucursal principal** del centro y su usuario quiosco (ADR-0010).
      Liga `gym_profile` → `branch_id` de la sucursal principal (nombre, teléfono
      y dirección de la ubicación física original). `gym_config` → `center_id`
      del centro.
   3. Crea los usuarios con su rol (superadmin/cuentas del sistema se crean fuera o
      después; el admin inicial del centro puede quedar como `CENTER_ADMIN`).
   4. Asigna `center_id` a todas las filas de las tablas del mapeo (ADR-0001), en el
      orden del flujo de entidades: catálogos → socios → turnos → transacciones →
      suscripciones → check-ins → ventas.
   5. Crea los members semilla internos del centro si no existen ("Público en
      General" / "Visita", ver ADR-0005).
   6. Imprime **conteos por tabla antes y después** para verificación manual.
3. **Reanudación**: no hay. Si el script falla a la mitad, se descarta la base de
   trabajo, se restaura el backup y se reintenta desde el inicio (la operación es
   idempotente en la práctica porque parte del backup limpio).
4. **Integridad**: conteos antes/después por tabla + spot-checks manuales sobre
   reportes del sistema migrado. **Sin pruebas automatizadas** — decisión explícita
   del plan de origen (no invertir tiempo ahí).
5. **No corre contra producción**: el resultado de la base de trabajo se convierte en
   la nueva base del centro (mismo flujo que un restore).

## Consecuencias

- Simple y repetible por cliente nuevo; el mismo script sirve para alta de centros
  futuros con backup similar (aunque para clientes nuevos se espera alta directa
  desde la UI de superadmin, no migración).
- Falla = reintento completo; los backups se hacen rápido, el costo aceptable.
- Riesgo: conteos iguales no garantizan correspondencia fila-a-fila; los spot-checks
  manuales son la red (reportes de suscripciones activas, saldos de turnos cerrados).

## Alternativas consideradas

- **Checkpoints/reanudación**: más robusto para bases muy grandes, pero duplica la
  complejidad del script; se descarta por tiempo.
- **Verificación automática de integridad referencial post-migración**: contradice la
  decisión del plan de origen; los conteos + spot-checks son suficientes para una
  operación única y supervisada.
- **Migración en línea (sin backup)**: descartada — el script nunca debe escribir
  sobre la única copia de los datos.
