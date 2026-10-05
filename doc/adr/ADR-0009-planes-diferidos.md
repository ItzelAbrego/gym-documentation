# ADR-0009: Planes de funcionalidades por centro diferidos

**Estado**: Aceptada · **Fecha**: 2026-09-21

## Contexto

El doc base pide que el superadministrador *"cambie/asigne planes (funcionalidades)
a cada centro"* y que al crear un centro *"se le debe asignar un plan"*. El mismo
documento lista `plans / center_plans` como "(fase posterior de planes)" en sus
tablas nuevas, sin definir qué es un plan: ¿catálogo de funcionalidades
habilitadas?, ¿límites (núm. de socios/usuarios)?, ¿precio/facturación del SaaS?

Ningún ADR ni story cubría el tema y [ST-006](../stories/ST-006-api-superadmin-centros.md)
creaba centros sin plan, en tensión con el requisito del doc base (ver
[P-07](../preguntas-y-respuestas.md), resuelta: diferir formalmente).

## Decisión

1. **Los planes quedan diferidos a una fase posterior.** No se crean las tablas
   `plans` / `center_plans` en esta fase.
2. **Los centros se crean sin plan**: ST-006 no asigna plan y todos los centros
   operan con todas las funcionalidades activas.
3. El requisito del doc base queda **registrado como pendiente** (no descartado):
   al entrar la fase de planes se deberá definir, como mínimo:
   - Qué es un plan (funcionalidades, límites, precio).
   - Enforcement: ¿bloqueo en backend, ocultamiento en frontend, o solo
     informativo para el superadmin?
   - Qué pasa con los datos existentes de un centro cuando su plan **quita** una
     funcionalidad ya usada (p. ej. inventario con artículos).
   - Nomenclatura: resolver la colisión con "Planes" de membresías vendidas a
     socios (`membership_config`/`rates`) — P-08.
4. Cuando los planes entren, los centros ya existentes reciben el **plan completo
   por defecto** de forma retroactiva, para que el enforcement no apague
   funcionalidades en uso.

## Consecuencias

- ST-006 queda conforme al doc modificado: alta de centro = centro +
  `CENTER_ADMIN` + usuario quiosco + socios semilla + configuraciones, sin plan.
- Cero retrabajo en esta fase: no hay nada que quitar después, solo agregar.
- Riesgo aceptado: si los planes llegan tarde, varios centros acumulan uso de
  funcionalidades que un plan futuro podría restringir; la regla 4 (plan completo
  retroactivo) acota ese riesgo a un momento de migración controlada.

## Alternativas consideradas

- **Mínimo viable ahora** (catálogo de planes + asignación + enforcement):
  requiere definir el modelo comercial del SaaS que aún no existe; sería diseño a
  ciegas con alto riesgo de retrabajo.
- **Feature flags por centro sin "plan"**: resuelve enforcement pero no el modelo
  comercial, y agrega complejidad de configuración sin demanda actual.
