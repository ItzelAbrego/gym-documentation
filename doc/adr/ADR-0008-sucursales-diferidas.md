# ADR-0008: Sucursales diferidas; configuraciones ligadas a Centro

**Estado**: Sustituida parcialmente por [ADR-0010](ADR-0010-sucursales-contabilidad-aislada.md) · **Fecha**: 2026-09-21

> **Nota (2026-09-21)**: las sucursales dejaron de diferirse — se diseñan en
> ADR-0010 con contabilidad aislada por sucursal. De esta ADR siguen vigentes:
> la cascada de configuraciones centro → sucursal como fase posterior y el
> registro del costo aceptado de mover FKs.

## Contexto

El plan de origen contempla la tabla `sucursales` (branches) con dos preguntas
abiertas: ¿qué tan difícil es que las configuraciones apunten a Centros y luego se
cambien a Sucursales? y ¿se relaciona algo directamente con Sucursales? También
planteaba crear desde ya configuraciones heredables por sucursal.

## Decisión

1. **Las sucursales quedan diferidas.** No se crea la tabla en esta fase y **ningún
   dato se liga directamente a sucursales** (criterio _strict need to be related
   basis_ del plan de origen).
2. **Las configuraciones se ligan a Centro desde el inicio**: `gym_config`,
   `gym_config_history` y `gym_profile` reciben `center_id`.
3. **Cardinalidad objetivo cuando entren las sucursales: 1 centro : N sucursales.**
   Cada sucursal pertenece a exactamente un centro; el centro sigue siendo el
   límite de aislamiento multi-tenant (`center_id`). La sucursal será una
   **sub-división interna del centro**, no un tenant nuevo.
4. **Migrar de Centro a Sucursal después es de bajo costo**: es renombrar/mover la
   FK (`center_id` → `branch_id`) o insertar la capa (centro → sucursal). El costo
   declarado al decidir acepta ese trabajo futuro.
5. **Los datos financieros/de auditoría no se ligarán a sucursales** (regla del
   doc base): aunque una sucursal se elimine, transacciones, ventas y turnos deben
   permanecer. Cuando entren sucursales, esas tablas quedan a nivel centro.
6. **No se diseña heredabilidad por sucursal ahora** (tabla de configuraciones con
   override por sucursal). Cuando las sucursales entren al roadmap se evalúa una
   jerarquía de configuración en cascada: centro → sucursal, donde la sucursal
   hereda lo del centro y solo pisa los valores propios.

## Consecuencias

- Alta de centros sin la complejidad de jerarquía centro/sucursal.
- Riesgo documentado: si las sucursales llegan pronto, las configuraciones por
  centro se tendrán que partir; el costo fue aceptado como bajo (FK renombrable).
- La UI de Configuración del centro no cambia en esta fase.

## Alternativas consideradas

- **Diseñar heredabilidad ya** (configs por centro + override por sucursal): más
  trabajo inicial sin demanda real hoy.
- **Dejar configuraciones globales por ahora**: migración más simple, pero los datos
  de perfil del gym quedarían sin dueño y la deuda crece.
