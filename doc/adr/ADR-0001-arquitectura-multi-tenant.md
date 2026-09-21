# ADR-0001: Multi-tenancy con esquema compartido y columna discriminatoria `center_id`

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

FitRoom es hoy un sistema monocentro: no existe ningún concepto de centro/tenant en el
código (verificado en `User`, `Member`, `WorkShift` y repositorios) y la base MySQL
(`fitroom`) contiene todas las tablas operativas sin dueño. Para operar como SaaS con
múltiples centros de gym se necesita aislar los datos de cada cliente.

Opciones evaluadas: base de datos por tenant, esquema MySQL por tenant, y esquema
compartido con columna discriminatoria.

## Decisión

**Esquema compartido (shared schema)** con una columna `center_id` (FK a `centers`) en
todas las tablas operativas. Reglas:

1. Toda fila de datos operativos pertenece exactamente a un centro.
2. Toda consulta operativa se filtra por el centro del usuario autenticado (claim del
   JWT, ver ADR-0004); el cliente nunca envía el centro.
3. Los catálogos geográficos `states`, `cities`, `colonias` quedan **compartidos** entre
   centros (no llevan `center_id`).

Tablas que reciben `center_id` (mapeo derivado de `schema.sql` y verificado contra las
entidades):

| Grupo | Tablas |
| --- | --- |
| Acceso y roles | `users` (nullable, ver ADR-0003), `gym_profile`, `gym_config`, `gym_config_history` |
| Socios | `members`, `member_fingerprint_templates`, `member_status` |
| Catálogos y tarifas | `membership_config`, `rates`, `rates_table_history`, `rate_allowed_methods` |
| Turnos y dinero | `work_shifts`, `work_shifts_notes`, `debit_transactions`, `cancellations` |
| Suscripciones | `member_membership`, `subscriptions`, `subscription_history`, `courtesies`, `courtesy_history` |
| Check-in | `check_in`, `check_out`, `checkin_subscription`, `checkin_courtesy`, `invalid_check_ins` |
| Ventas e inventario | `articles`, `inventory`, `sale`, `sales_articles`, `sales_details`, `purchase`, `purchase_details` |

Nota: tablas de detalle/historial pueden heredar el centro de su tabla padre
(`check_out` → `check_in`; `subscription_history` → `subscriptions`); se decide por
costo de consulta, pero la FK padre siempre dentro del mismo centro.

## Consecuencias

**Positivas**

- Un solo despliegue y una sola base; migración desde el esquema actual simple (agregar
  columnas, no mover esquemas).
- Operación multi-centro barata (un JVM, jobs de expiración existentes en
  `application.yml` procesan todo con filtro por centro).

**Negativas / riesgos**

- Disciplina: cualquier query nuevo sin filtro de centro es una fuga de datos entre
  clientes. Mitigación: verificación por revisión + tests de scoping (ST-013).
- Query lentos por falta de filtro de centro no fallan, simplemente mezclan datos: la
  validación debe ser activa en revisión de código.
- Hallazgos concretos a corregir en el camino (verificados en código):
  - `WorkShiftRepository.findOpenWorkShift()` asume un único turno abierto **global**
    → debe pasar a `(... WHERE ws.centerId = :centerId ...)`.
  - `CheckIn.registerTimestamp` tiene UNIQUE global (`CheckIn.java:38`,
    `schema.sql:207`) → dos centros con check-in en el mismo segundo colisionarían;
    quitar el unique o hacerlo compuesto con `center_id`.
  - `MemberRepository.findByCellPhone/findByEmail` y sus validaciones en
    `MemberService` son globales → ver ADR-0005.
- La vista `vw_member_today_status` (`schema.sql:461`) y los jobs programados
  (`scheduler` de expiración de tarifas, suscripciones y cortesías) operan sobre todas
  las filas; al introducir `center_id` deben conservar semántica global (procesan
  todos los centros) o recibir el centro como parámetro según el caso.

## Alternativas consideradas

- **Base de datos por tenant**: aislamiento máximo, pero multiplicar infraestructura,
  despliegues y herramientas de reporting; inviable para el tamaño del equipo.
- **Esquema por tenant (una BD, N esquemas MySQL)**: mejor aislamiento que shared
  schema, pero obliga a connection routing dinámico, migraciones N-veces y complica
  las vistas/queries de superadministrador.
