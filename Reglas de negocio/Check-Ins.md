## **Contexto**
---
Al existir distintos tipos de planes de suscripción, pueden presentarse diversos casos al momento de registrar el primer Check-In de un socio. Cada escenario se rige por reglas específicas según el tipo de plan, su fecha de inicio y el estado de la suscripción al momento del Check-In.

## **Funcionamiento de Check-Ins**
---
### **Check-in creado desde una suscripción sesión general**

Cuando se realiza una transacción asociada a una suscripción de tipo Sesión a Público General (es decir, no vinculada a un socio específico), el sistema genera un Check-in de forma automática. Este Check-in no permite la opción de realizar un Check-out manual, ya que las sesiones están diseñadas para uso de público general.

Las sesiones activas serán expiradas automáticamente por el job programado a la medianoche, momento en el cual se dará por concluida la sesión y se liberará el recurso asociado.

### **Check-in creado desde una suscripción sesión socio**

Cuando se realiza una transacción asociada a una suscripción de tipo Sesión con Socio, el sistema genera el Check-in de forma automática. En este caso, al estar vinculada a un socio, el Check-out podrá realizarse con normalidad, conforme a las condiciones y vigencia de la suscripción correspondiente.

Una vez realizado el Check-out, si el socio intenta registrar un nuevo Check-in y su suscripción ya no cubre otra sesión, el sistema mostrará el estado "Sin Suscripción", indicando que no cuenta con una suscripción activa que le permita continuar.
### **Creación de cortesia sesión no crea check-in** 

Al generar una Cortesía de tipo Sesión, el sistema no creará ningún Check-in de forma automática. Una vez emitida la cortesía, el socio podrá registrar su Check-in y Check-out con normalidad, siguiendo el flujo habitual de una sesión con socio. Creación de suscripciones distintas a sesiones no crean checkin.

Una vez realizado el Check-out, si el socio intenta registrar un nuevo Check-in y su suscripción ya no cubre otra sesión, el sistema mostrará el estado "Sin Suscripción", indicando que no cuenta con una suscripción activa que le permita continuar.
### **Creación de check-in suscripciones**

Al crear una suscripción, el sistema **no generará un Check-in de forma automática**. En su lugar, el socio deberá registrar sus Check-ins y Check-outs con normalidad durante el periodo de vigencia de la suscripción.

## **Casos de registro de check-Ins**
---

- [ ] **Registro de suscripción tipo sesión a público general**: genera Check-In automático, sin Check-Out.
- [ ] **Registro de suscripción tipo sesión relacionada a un socio**: genera Check-In automático, permitiendo que el socio genere su Check-Out.
- [ ] **Registro de suscripción tipo sesión programada relacionada a un socio**: no genera Check-In automático. Se marca como vigente y permite al socio crear el Check-In y Check-Out según el Start Date.
- [ ] **Registro de suscripción (no tipo sesión)**: no genera Check-In automático.
- [ ] **Check-In registrado 3 días antes del End Date de la suscripción**: marca Check-In y Check-Out con estado **Próximo a vencer**.
- [ ] **Check-In registrado en fecha de End Date**: marca Check-In y Check-Out con estado **Vencido**.
- [ ] **Check-In y Check-Out un día después del término de la suscripción sin renovar**: se registra con estado **Sin Suscripción** (Check-In suelto).
- [ ] **Cortesía de tipo sesión**: no genera Check-In automático. El usuario debe registrarlo por su cuenta.
- [ ] **Check-In luego de Check-Out de una cortesía tipo sesión**: al no estar cubierto por una suscripción, se registra como **Sin Suscripción** (Check-In suelto).