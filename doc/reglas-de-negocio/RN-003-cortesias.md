---
id: RN-003
tipo: regla-de-negocio
titulo: Cortesías
estado: vigente
fecha: 2026-10-09
---
# RN-003 — Cortesías

**Estado**: Vigente · **Fecha**: 2026-10-09 · **Relacionado**: [RN-001 — Planes](RN-001-planes.md), [RN-002 — Suscripciones](RN-002-suscripciones.md), [RN-004 — Check-Ins](RN-004-check-ins.md)

## Contexto

El registro de cortesías se realiza desde el apartado **Cortesías**, el cual es visible únicamente para los usuarios con rol de administrador. Las cortesías no tienen una duración predeterminada, ya que su vigencia depende exclusivamente del administrador, quien es el único que puede establecer la fecha de inicio y de término.

## Funcionamiento de cortesías

| Escenario                                                            | Comportamiento del sistema                                                                                                                                            |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Creación de nueva cortesía                                           | Solo los usuarios con rol de administrador pueden crear cortesías.                                                                                                    |
| Creación de cortesía programada                                      | Las cortesías no pueden ser futuras; el sistema bloquea la creación de cortesías con Start Date futuro.                                                               |
| Creación de cortesía de tipo sesión                                  | No genera Check-In automático. Solo puede asociarse a un socio registrado y no admite fecha futura.                                                                   |
| Creación de cortesía cuando el socio cuenta con una cortesía vigente | Un socio no puede tener más de una cortesía vigente al mismo tiempo. Si se intenta crear una nueva, el sistema marcará la cortesía anterior como **Vencida**.         |
| Creación de cortesía con suscripción activa                          | Si el socio tiene una suscripción activa y se registra una cortesía a su nombre, la suscripción se marcará como **Vencida**, mientras que la cortesía quedará activa. |

## Casos de creación de cortesías

| Caso                                                                                  | Comportamiento esperado                                                                                           |
| ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **Solo los usuarios con rol de administrador tienen acceso al apartado de Cortesías** | Sistema bloquea el ingreso de un usuario de tipo staff al apartado de cortesías.                                  |
| **Creación de cortesía con start date futuro**                                        | El sistema bloquea la creación de cortesías con un start date futuro.                                             |
| **Cortesía de tipo sesión no genera Check-In automático**                             | Al registrar una cortesía de tipo sesión, no se mostrará un registro de check-in hasta que el usuario lo realice. |
| **Creación de cortesía con una cortesía vigente**                                     | La cortesía anterior se marca como **Vencida**.                                                                   |
| **Creación de cortesía con suscripción vigente**                                      | La suscripción activa del socio se marca como **Vencida**.                                                        |
| **La creación de una cortesía será exclusiva para socios registrados**                | No podrá crearse una cortesía sin relacionarse a un socio.                                                        |
