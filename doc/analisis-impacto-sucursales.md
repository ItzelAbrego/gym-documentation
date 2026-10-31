# Análisis de impacto: entrada de sucursales sobre el schema multi-tenant

**Fecha**: 2026-10-30 · **Alcance**: `Center-feature-branch` (tip `9151fa89`) vs
[`doc/schema-propuesta.sql`](schema-propuesta.sql) · **ADRs**:
[ADR-0008](adr/ADR-0008-sucursales-diferidas.md),
[ADR-0010](adr/ADR-0010-sucursales-contabilidad-aislada.md)

## Conclusión

Incorporar sucursales **no requiere refactor del trabajo hecho**. Es una
**adición de campos**: ninguna columna `center_id` ya implementada se elimina ni
se reemplaza. Las stories que lo cubren ya existen
([ST-015](stories/ST-015-tabla-branches-y-admin.md),
[ST-016](stories/ST-016-scoping-por-sucursal.md)).

El avance "por centro primero, sucursal después" resultó ser la **secuencia
correcta de construcción**, no una concesión: `center_id` es una pieza
estructural del diseño final (ver §3).

## 1. Contexto: la contradicción documental que originó la revisión

Existía una inconsistencia entre decisiones:

| Documento | Qué dice sobre sucursales |
| --- | --- |
| Plan maestro (antes de este PR) | "Las sucursales quedan pospuestas"; "nada se liga directamente a Sucursales" |
| [ADR-0008](adr/ADR-0008-sucursales-diferidas.md) (2026-09-21) | Sucursales **diferidas**; todo se liga a Centro |
| [ADR-0010](adr/ADR-0010-sucursales-contabilidad-aislada.md) (2026-09-21, **vigente**) | Sucursales **desde el inicio**; sustituye parcialmente a ADR-0008 |
| Stories ST-004/010/015/016 y `schema-propuesta.sql` | Alineadas con ADR-0010 (modelo completo de sucursales) |
| Código mergeado (V696–V701) | Implementa el modelo de ADR-0008 (solo `center_id`) |

ADR-0008 fue revertida por ADR-0010 el mismo día, al aparecer el requisito de
**contabilidad exacta y separada por sucursal**. Las stories y el schema
propuesto se actualizaron; el plan maestro y el código no. Este PR corrige el
plan maestro; el código queda cubierto por ST-015/ST-016.

## 2. Verificación: ninguna columna `center_id` se elimina

Se cruzaron las **18 tablas que recibieron `center_id`** en el código mergeado
(`V202403121697` para `users` + `V202403121699` para el resto) contra el schema
objetivo, tabla por tabla.

**Resultado: 18 de 18 conservan `center_id`. Cero eliminaciones.**

| Efecto | Nº | Tablas |
| --- | --- | --- |
| Sin cambio alguno | 11 | `members`, `subscriptions`, `member_membership`, `courtesies`, `member_status`, `member_fingerprint_templates`, `rates`, `rate_allowed_methods`, `membership_config`, `articles`, `gym_config` |
| Ganan `branch_id` (aditivo) | 7 | `work_shifts`, `debit_transactions`, `sale`, `purchase`, `inventory`, `check_in`, `invalid_check_ins` |

## 3. Por qué se necesitan AMBOS campos (`center_id` + `branch_id`)

No es redundancia. El `center_id` es **la mitad de la llave compuesta** que
garantiza el aislamiento contable (ADR-0010 regla 3):

```sql
CONSTRAINT fk_sale_branch_center FOREIGN KEY (branch_id, center_id)
    REFERENCES branches(id, center_id)
```

Esto requiere `UNIQUE KEY (id, center_id)` en `branches`.

**Qué pasaría con solo `branch_id`:** una FK simple a `branches(id)` valida que la
sucursal *exista*, pero **no** que pertenezca al centro de la fila. Un bug podría
insertar una venta con el `branch_id` de la sucursal de **otro centro**, mezclando
la contabilidad entre tenants. Con la FK compuesta, el motor **rechaza** esa fila.

Reparto de responsabilidades:

- **`center_id`** → a qué tenant pertenece la fila (aislamiento multi-tenant; es
  el claim `center_uuid` del JWT).
- **`branch_id`** → en qué sucursal física ocurrió (contabilidad y operación).
- **FK compuesta** → amarra ambos: imposible cruzar centro y sucursal.

Beneficios secundarios de conservar `center_id`: reportes consolidados por centro
sin `JOIN` a `branches`, e índice directo (`idx_*_center_id`).

## 4. Delta pendiente para sucursales

| Operación | Cantidad |
| --- | --- |
| `CREATE TABLE` | **2** (`branches`, `branch_stock`) |
| `ALTER TABLE ... ADD COLUMN branch_id` + FK | **~13** |
| `DROP COLUMN center_id` | **0** |
| Re-scoping del trabajo por centro ya hecho | **0** |

Tablas que portan `branch_id` en el schema objetivo (14): `users` (nullable por
rol), `work_shifts`, `work_shifts_notes`, `debit_transactions`, `cancellations`,
`check_in`, `check_out`, `invalid_check_ins`, `inventory`, `sale`,
`sales_details`, `purchase`, `branch_stock` (nueva), `gym_profile`.

Tablas de detalle que **heredan** la sucursal del padre (sin columna propia):
`sales_articles`, `purchase_details`, `checkin_subscription`, `checkin_courtesy`.

## 5. Excepciones y matices (no invalidan la conclusión)

1. **`gym_profile`** es el único caso que el schema marca como reemplazo
   (`[CAMBIO] era center_id` → `branch_id`). En el código **nunca recibió
   `center_id`**: `V202403121699` solo tocó `gym_config`. En la práctica recibirá
   `branch_id` directo, sin eliminación. La anotación del schema se refiere al
   `schema.sql` original, no a lo implementado.
2. **`articles.stock` se retira** del dominio, sustituido por `branch_stock` como
   única fuente de verdad (ADR-0010, N-08). Es el **único cambio destructivo** del
   modelo de sucursales y no involucra `center_id`.
3. **Cambio de lógica, no de schema**: `findOpenWorkShift` pasa de "un turno
   abierto por centro" a "por sucursal" (ST-016).
4. **Tipos de clave**: `centers.id` se implementó como `BIGINT`. El schema
   propuesto se corrigió de `INT UNSIGNED` a `BIGINT` en este mismo PR, requisito
   para que las FK compuestas sean válidas (ADR-0010, N-02).

## 6. Riesgo real: datos transaccionales sin sucursal

El schema es aditivo e indoloro. El único punto de cuidado es distinto: las filas
de dinero y operación creadas **antes** de que exista `branch_id` deben recibir
una sucursal en el backfill.

- Con **una sola sucursal**: trivial. ST-014 ya especifica crear la **sucursal
  principal** del centro migrado y apuntar todo `branch_id` histórico a ella.
- Con **varias sucursales operando** antes del backfill: el dato de "dónde
  ocurrió" no es recuperable.

Implicación práctica: mientras la operación sea single-sucursal, diferir
sucursales no tiene costo de datos.

## 7. Estado de las stories que cubren esto

| Story | Alcance | Ticket |
| --- | --- | --- |
| [ST-015](stories/ST-015-tabla-branches-y-admin.md) | Tabla `branches` + administración de sucursales | [17tjnm2vmtt](https://app.clickup.com/t/17tjnm2vmtt) |
| [ST-016](stories/ST-016-scoping-por-sucursal.md) | `branch_id`, contexto de sucursal, `branch_stock` | [17tjnm2vmtv](https://app.clickup.com/t/17tjnm2vmtv) |

Ambas existen, están priorizadas como `high` y no requieren deshacer trabajo
previo.

## Método de verificación

- Migraciones leídas desde `origin/Center-feature-branch` (`9151fa89`):
  `V202403121696`–`V202403121701`.
- Tablas con `center_id` extraídas de los `ALTER TABLE` de `V202403121699`
  (18 tablas, incluyendo `users` vía `V202403121697`).
- Presencia de `center_id`/`branch_id` por tabla verificada sobre los bloques
  `CREATE TABLE` de `doc/schema-propuesta.sql`.
