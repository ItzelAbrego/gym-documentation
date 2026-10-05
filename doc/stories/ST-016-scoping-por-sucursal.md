---
id: ST-016
tipo: story
titulo: branch_id, contexto de sucursal y stock por sucursal
grupo: Principal
estado: pendiente
depende_de:
  - ST-004
  - ST-010
  - ST-015
adrs:
  - ADR-0010
  - ADR-0004
---

# ST-016 — `branch_id`, contexto de sucursal y stock por sucursal

**Grupo**: Principal · **Depende de**: ST-004, ST-010, ST-015 · **ADRs**: [ADR-0010](../adr/ADR-0010-sucursales-contabilidad-aislada.md), [ADR-0004](../adr/ADR-0004-jwt-claim-de-centro.md)

## Historia de usuario

**Como** centro con sucursales **quiero** que cada peso cobrado y cada artículo
vendido quede registrado en la sucursal donde ocurrió **para** mantener la
contabilidad de cada sucursal exacta y separada, sin mezclas.

## Criterios de aceptación

- [ ] Migración Flyway: `branch_id INT UNSIGNED NOT NULL` + FK + índice en las
      tablas de ADR-0010 regla 3: `work_shifts`, `work_shifts_notes`,
      `debit_transactions`, `cancellations`, `sale`, `sales_details`,
      `purchase`, `inventory`, `check_in`, `check_out`, `invalid_check_ins`.
- [ ] Migración Flyway crea `branch_stock` (`id`, `branch_id`, `article_id`,
      `quantity`, UNIQUE `(branch_id, article_id)`) y traslada los saldos de
      `articles.stock` a la sucursal principal (en la migración de datos, ST-014).
- [ ] Claims JWT: staff con sucursal lleva `branch_uuid` (además de
      `center_uuid`); el filtro lo expone como contexto igual que el centro
      (extensión de lo hecho en ST-010).
- [ ] Resolución del contexto de operación: staff/REGISTRATION siempre operan
      **su** sucursal (del token); `ADMIN`/`CENTER_ADMIN` (sin sucursal) eligen
      sucursal en la vista donde el registro la requiere (apertura de turno,
      check-in, venta) — el backend valida que la sucursal pertenezca al centro.
- [ ] **Un solo turno abierto por sucursal**:
      `WorkShiftRepository.findOpenWorkShift` pasa a filtrar por
      `center_id + branch_id` (sustituye la variante por centro de ST-004).
- [ ] Ventas y salidas/entradas de inventario descuentan/suman en `branch_stock`
      de la sucursal de la operación; `articles.stock` deja de ser fuente de
      verdad (queda como cache agregado o se elimina — decidir en esta story,
      preferido: eliminarlo del dominio).
- [ ] Check-in y ventas a socios: el socio sigue siendo del centro (cualquier
      sucursal lo atiende); el registro lleva la sucursal donde ocurrió.
- [ ] Reportes: corte de caja, ventas e inventario filtran por sucursal;
      `CENTER_ADMIN`/`ADMIN` pueden ver consolidado por centro y detalle por
      sucursal.
- [ ] Aprobación de turnos (ST-012) evalúa el horario/desfase de la sucursal
      del turno.
- [ ] Regresión con un solo centro/una sola sucursal: todo flujo actual opera
      igual apuntando a la sucursal principal.

## Notas técnicas

- Invariante contable: toda `debit_transaction` nace dentro de un
  `work_shift` con `branch_id` → la sucursal del dinero es inmutable. Las
  tablas de detalle (`sales_articles`, `purchase_details`,
  `checkin_subscription`, `checkin_courtesy`) heredan la sucursal del padre;
  no llevan columna propia.
- Mismo nivel de mitigación que el scoping de centro (ST-013): una query de
  caja/ventas/inventario sin filtro de sucursal es una mezcla contable —
  revisión + prueba de aislamiento por sucursal en los endpoints de dinero.
- Catálogos (`rates`, `membership_config`, `articles`) quedan a nivel centro;
  override de precios por sucursal = fase posterior (ADR-0010 regla 10).
