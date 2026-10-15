---
id: RN-001
tipo: regla-de-negocio
titulo: Planes de suscripción
estado: vigente
fecha: 2026-10-09
---
# RN-001 — Planes de suscripción

**Estado**: Vigente · **Fecha**: 2026-10-09 · **Relacionado**: [RN-002 — Suscripciones](RN-002-suscripciones.md), [RN-003 — Cortesías](RN-003-cortesias.md), [RN-004 — Check-Ins](RN-004-check-ins.md)

## Contexto

Fit-Manage permite la creación de distintos tipos de planes según el cliente lo decida. Los planes de duración menor a una mensualidad (sesión, semanal, quincenal) se calculan en días fijos, mientras que los de mayor duración (mensual, trimestral o semestral) se ajustan a meses naturales del calendario:

- **Sesión**: 1 día
- **Semanal**: 7 días
- **Quincenal**: 15 días
- **Mensual**: 1 mes natural
- **Trimestral**: 3 meses naturales
- **Semestral**: 6 meses naturales
- **Anual**: 12 meses naturales
- **Otro**: el usuario define libremente la cantidad de días de vigencia

> **Nota:** Los planes Mensual, Trimestral, Semestral y Anual se calculan tomando como referencia los meses naturales del calendario, por lo que su duración exacta puede variar según el mes de inicio de la suscripción.

## Creación de planes

La creación de planes solo puede realizarse desde el apartado **Planes**, el cual está disponible únicamente para los usuarios con rol de administrador. Para la creación de un nuevo plan se plantearon los siguientes puntos:

| Caso                                                                                    | Comportamiento esperado                                                                                     |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Creación de dos planes con el mismo nombre**                                          | Sistema bloquea la creación de un segundo plan bajo el mismo nombre.                                        |
| **Es posible crear más planes que compartan el mismo periodo de suscripción cubierto.** | Se permite crear mientras no contengan el mismo nombre.                                                     |
| **Los métodos de pago son configurables.**                                              | Usuario con rol administrador puede seleccionar los métodos de pago disponibles según el plan seleccionado. |