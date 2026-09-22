# ADR-0010: Sucursales — diseño propio y contabilidad aislada por sucursal

**Estado**: Aceptada · **Fecha**: 2026-09-21 · **Sustituye parcialmente a** [ADR-0008](ADR-0008-sucursales-diferidas.md) (las sucursales dejan de ser diferidas; lo diferido queda solo: precios por sucursal y heredabilidad de configuraciones)

## Contexto

[ADR-0008](ADR-0008-sucursales-diferidas.md) difirió las sucursales por no haber
demanda clara. Al preparar la propuesta al cliente se decidió **diseñarlas ya**,
con un requisito central: **la contabilidad de cada sucursal debe mantenerse
exacta y separada — sin mezclas entre sucursales**. Esto parece chocar con la
regla del doc base ("los datos financieros no pueden estar ligados a sucursales;
si son eliminadas, deben permanecer"), pero ambas se satisfacen a la vez:

1. Todo movimiento de dinero lleva `branch_id` → cortes y reportes por sucursal.
2. Las sucursales **solo se desactivan, nunca se borran físicamente** → la
   contabilidad histórica y todas las FK sobreviven intactas para siempre.

## Decisión

### Modelo

1. **Cardinalidad 1 centro : N sucursales.** Nueva tabla `branches`:
   `id` INT UNSIGNED auto-increment (PK/FK interna), `branch_uuid` BINARY(16)
   UNIQUE (externo, igual que `center_uuid` en ADR-0002), `center_id` NOT NULL,
   `name`, `active`, timestamps. **El centro sigue siendo el límite del tenant**
   (claim `center_uuid`); la sucursal es sub-división interna, nunca un tenant.
2. **Solo desactivación lógica**: `active` flag; no existe borrado físico de
   sucursales (protege regla auditoría: turnos, ventas y transacciones históricas
   de una sucursal inactiva permanecen consultables).
3. **`branch_id` NOT NULL en las tablas de dinero y operación en sucursal**:
   `work_shifts`, `work_shifts_notes`, `debit_transactions`, `cancellations`,
   `sale`, `sales_details`, `purchase`, `inventory`, nuevo `branch_stock`,
   `check_in`, `check_out`, `invalid_check_ins`. Las tablas de detalle puras
   (`sales_articles`, `purchase_details`, `checkin_subscription`, `checkin_courtesy`)
   **heredan** la sucursal de su padre (misma regla de herencia que ADR-0001).
   **Invariante centro↔sucursal**: toda tabla operativa con `center_id` +
   `branch_id` referencia la sucursal vía FK compuesta
   `FOREIGN KEY (branch_id, center_id) REFERENCES branches(id, center_id)`
   (requiere `UNIQUE KEY (id, center_id)` en `branches`). La FK simple a
   `branches(id)` valida que la sucursal exista, pero no que pertenezca al
   centro de la fila: sin la compuesta, una fila podría quedar ligada a la
   sucursal de **otro centro** y mezclar contabilidad entre tenants.
4. **Socios son del centro** (`members.center_id`, sin `branch_id`): un socio se
   registra una sola vez y puede entrar a **cualquier sucursal de su centro**;
   cada check-in/venta queda marcado con la sucursal donde ocurrió. Igual para
   `subscriptions`, `member_membership`, `courtesies`, `member_status`,
   `member_fingerprint_templates`: el beneficio es del centro; el dinero que lo
   originó vive en la `debit_transaction` de la sucursal donde se cobró.
5. **Staff por sucursal**: `users.branch_id` NULL permitido; los roles
   `STAFF`, `REGISTRATION` (incl. usuarios quiosco) **requieren** sucursal;
   `ADMIN` y `CENTER_ADMIN` pueden operar cualquier sucursal de su centro
   (`branch_id` NULL = ámbito de todo el centro). El usuario quiosco
   `CHECKIN_<slug>` (P-04) es **uno por sucursal**. `users` usa la misma FK
   compuesta de la regla 3: con `branch_id` NULL no se evalúa (comportamiento
   estándar de MySQL) y rige la FK a `centers`.
6. **Turno de caja por sucursal**: máximo un turno abierto por sucursal
   (`findOpenWorkShift` pasa a por-branch). El corte de caja se calcula de la
   sucursal del turno; el `CENTER_ADMIN` ve reportes por sucursal y el
   consolidado del centro. La aprobación de turnos fuera de horario (ADR-0006)
   evalúa el horario de la sucursal del turno.
7. **Catálogos del centro, stock por sucursal**: `rates`, `membership_config`,
   `rate_allowed_methods` y el catálogo de `articles` son del centro (precio
   único; override de precios por sucursal = fase posterior). El stock deja de
   vivir solo en `articles.stock`: nueva tabla **`branch_stock`**
   (`branch_id`, `article_id`, `quantity`) como saldo por sucursal; los
   movimientos de `inventory` llevan `branch_id`. Ventas descuentan el stock de
   la sucursal donde ocurren. Todas las ubicaciones de una venta/compra caen en
   la sucursal de la operación.
8. **JWT con claim de sucursal** (extensión de ADR-0004): usuarios con sucursal
   llevan `branch_uuid` además de `center_uuid`; el filtro los expone como
   contexto. Staff solo opera su sucursal; `ADMIN`/`CENTER_ADMIN` sin
   `branch_uuid` operan el centro completo (selección de sucursal en pantalla
   para registros, p. ej. apertura de turno, es dato del contexto de la vista,
   no del tenant).
9. **Alta de centro** (ST-006) crea además la **sucursal principal** del centro
   y su usuario quiosco. **Migración** (ST-014): se crea la sucursal principal
   del centro migrado y todo `branch_id` histórico apunta a ella.
10. **Configuraciones**: `gym_config`/`gym_profile` quedan a nivel centro. La
    cascada centro → sucursal para configuraciones y precios por sucursal se
    difiere (fase posterior), igual que los planes (ADR-0009).

### Contabilidad aislada — cómo se garantiza "sin mezclas"

- Toda entrada/salida de dinero nace dentro de un `work_shift` que tiene
  `branch_id` → cada peso tiene sucursal de origen inmutable.
- El aislamiento se valida en el mismo nivel que el scoping de centro (ST-013):
  queries de caja, ventas e inventario filtran por sucursal del contexto.
- Reportes: por sucursal para operación; consolidado por centro para
  `CENTER_ADMIN` (y superadmin impersonando).

## Consecuencias

- ST-004/ST-013 crecen: `branch_id` y scoping por sucursal además del de centro.
- ST-006: el alta de centro incluye sucursal principal + quiosco de la sucursal.
- ST-010: el JWT pasa a claims `center_uuid` + `branch_uuid` (nullable).
- Se agregan stories nuevas: tabla `branches` + scoping (ver README, ST-015 y
  ST-016) y vista mínima de administración de sucursales del centro.
- `articles.stock` deja de ser la fuente de verdad del stock (queda como cache
  o se migra a `branch_stock`; se decide en ST-016, preferida migración).
- Riesgo de omitir filtro de sucursal = mezclas contables: mismo nivel de
  mitigación que el scoping de centro (revisión + pruebas de aislamiento).

## Alternativas consideradas

- **Socios por sucursal**: duplica fichas de la misma persona y rompe la
  unicidad por centro ya decidida (ADR-0005).
- **Staff flotante entre sucursales**: flexible, pero permite operar cajas
  "ajenas" y difumina dónde ocurrió cada cobro.
- **Todo el catálogo por sucursal**: aislamiento total pero duplica tarifas y
  artículos en cada sucursal; encarece abrir sucursales.
- **Borrado con snapshot** (congelar nombre/datos de sucursal en cada
  transacción histórica): permite borrar sucursales, pero duplica datos y abre
  la puerta a perder trazabilidad; solo se retomará si aparece necesidad real
  de borrado.
- **Seguir difiriendo sucursales** (ADR-0008 original): contradice el requisito
  del cliente de contabilidad separada por sucursal desde el inicio.
