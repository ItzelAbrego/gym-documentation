## **Contexto**
---
El registro de cortesías se realiza desde el apartado **Cortesías**, el cual es visible únicamente para los usuarios con rol de administrador. Las cortesías no tienen una duración predeterminada, ya que su vigencia depende exclusivamente del administrador, quien es el único que puede establecer la fecha de inicio y de término.
## **Funcionamiento de cortesías**
---

| Escenario                                                            | Comportamiento del sistema                                                                                                                                            |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Creación de nueva cortesía                                           | Solo los usuarios con rol de administrador pueden crear cortesías.                                                                                                    |
| Creación de cortesía programada                                      | Las cortesías no pueden ser futuras; el sistema bloquea esta acción.                                                                                                  |
| Creación de cortesía de tipo sesión                                  | No genera Check-In automático. Solo puede asociarse a un socio registrado y no admite fecha futura.                                                                   |
| Creación de cortesía cuando el socio cuenta con una cortesía vigente | Un socio no puede tener más de una cortesía vigente al mismo tiempo. Si se intenta crear una nueva, el sistema marcará la cortesía anterior como **Vencida**.         |
| Creación de cortesía con suscripción activa                          | Si el socio tiene una suscripción activa y se registra una cortesía a su nombre, la suscripción se marcará como **Vencida**, mientras que la cortesía quedará activa. |
## **Casos de creación de cortesías**
---
- [ ] **Creación de cortesías**: solo los usuarios con rol de administrador tienen acceso al apartado de Cortesías.
- [ ] **Cortesía programada**: el sistema bloquea la creación de cortesías con fecha futura.
- [ ] **Cortesía de tipo sesión**: no genera Check-In automático y solo puede crearse para un socio registrado.
- [ ] **Creación de cortesía con una cortesía vigente**: la cortesía anterior se marca como **Vencida**.
- [ ] **Creación de cortesía con suscripción vigente**: la suscripción activa del socio se marca como **Vencida**.