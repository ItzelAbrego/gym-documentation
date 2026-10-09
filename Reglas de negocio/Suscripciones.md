## **Contexto**
---
Las suscripciones se crean desde el apartado **Nueva suscripción**. En él se llevan a cabo las transacciones correspondientes a la venta de un plan de suscripción. Una vez realizada la transacción, el sistema no generará ningún Check-In, salvo cuando se trate de suscripciones de tipo Sesión. En ese caso, únicamente se realizará la venta y el registro de la suscripción.

Las suscripciones pueden mostrar distintos estados según los días restantes para su vencimiento:

- **Estado programado**: el socio registra una suscripción con una fecha de inicio específica.

- **Estado vigente**: al llegar la fecha del _start date_, la suscripción se marca como vigente durante el periodo que cubra el plan contratado.

- **Próximo a vencer**: por defecto, cuando faltan 3 días para el _end date_, sin embargo, este dato podrá modificarse desde la configuración.

- **Vencida**: el día del _end date_.

- **Cancelada**: una suscripción solo podrá ser cancelada *dentro del turno donde se generó*, el sistema bloqueará los intentos de cancelación de suscripciones fuera del turno en el que fueron generadas. 
## **Vencimiento y renovación de la suscripción**
---

| Escenario                                   | Comportamiento del sistema                                                                                                                                                                                                                                                                                    |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Último día de la suscripción                | La suscripción se marca con el estado **Vencida**. Si el socio realiza un Check-in en esta fecha, este se registra como un Check-in suelto, es decir, no cubierto por la suscripción actual.                                                                                                                  |
| Renovación un día después del End Date      | Si el socio renueva su suscripción al día siguiente del vencimiento, la nueva fecha de Start Date será igual a la fecha de vencimiento de la suscripción anterior, manteniendo así la continuidad de cobertura.                                                                                               |
| Renovación tras varios días sin suscripción | Si transcurren varios días entre el vencimiento y la renovación, el Start Date de la nueva suscripción se considerará a partir del primer Check-in suelto que el socio haya realizado durante el periodo sin cobertura.                                                                                       |
| Continuidad sin interrupción                | Si el socio realiza un Check-in al día siguiente del vencimiento de su suscripción anterior, se considera que existe continuidad sin interrupción. En este caso, la nueva suscripción debe tener como fecha de inicio el último día de la suscripción anterior, asegurando que no existan días sin cobertura. |
## **Cálculo de próxima fecha de suscripción por socio** 
---
- [ ] **Socio recién creado sin Check-Ins**: fecha actual.
- [ ] **Socio con Check-Ins sin suscripciones (sueltos)**: fecha del primer Check-In sin suscripción.
- [ ] **Socio con cortesía activa**: fecha actual.
- [ ] **Socio con cortesía vencida o cancelada con un Check-In sin suscripción (suelto)**: fecha del primer Check-In sin suscripción.
- [ ] **Socio con visita activa o visita futura**: fecha del End Date + 1 día.
- [ ] **Socio con suscripción activa y suscripción programada**: fecha del End Date de la última suscripción.
- [ ] **Socio con sesión vencida y Check-Ins posteriores**: fecha del primer Check-In sin suscripción.
- [ ] **Socio con visita vencida y sin Check-Ins**: fecha actual.
- [ ] **Socio con suscripción vencida y sin Check-Ins posteriores**: fecha actual.
- [ ] **Socio con suscripción vencida y Check-In el End Date y al día siguiente**: fecha del End Date de la última suscripción.
- [ ] **Socio con suscripción que venció ayer y Check-In el último día**: fecha del End Date de la última suscripción.
- [ ] **Socio con suscripción vencida y Check-In el último día, pero no al día siguiente**: primer Check-In sin suscripción después de la fecha de término.
- [ ] **Socio con suscripción vencida, sin Check-In el último día pero sí en días posteriores**: primer Check-In sin suscripción después de la fecha de término.