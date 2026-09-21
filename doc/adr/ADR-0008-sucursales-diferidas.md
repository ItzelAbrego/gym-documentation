# ADR-0008: Sucursales diferidas; configuraciones ligadas a Centro

**Estado**: Aceptada · **Fecha**: 2026-09-21

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
3. **Migrar de Centro a Sucursal después es de bajo costo**: es renombrar/mover la
   FK (`center_id` → `branch_id`) o insertar una capa (centro → sucursal). El costo
   declarado al decidir acepta ese trabajo futuro.
4. **No se diseña heredabilidad por sucursal ahora** (tabla de configuraciones con
   override por sucursal). Si las sucursales entran al roadmap, se evalúa entonces
   una tabla `branch_config` con fallback a la del centro.

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
