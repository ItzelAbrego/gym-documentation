# Propuesta: FitRoom como SaaS multi-centro

**Para**: revisión y visto bueno del cliente · **Fecha**: 2026-09-21

Documento de lectura ejecutiva. El detalle técnico completo está en los anexos
(ADRs, stories, preguntas abiertas y esquema de base de datos propuesto).

---

## 1. Qué se propone

Convertir FitRoom —hoy un sistema para un solo gimnasio— en un **SaaS multi-centro**:
varios gimnasios (clientes) operando sobre la misma aplicación y la misma base de
datos, cada uno viendo únicamente su propia información.

Para lograrlo, cada registro operativo (socios, suscripciones, turnos, ventas,
check-ins, configuraciones…) queda ligado a un **Centro**, y el sistema garantiza
que ningún usuario pueda ver ni modificar datos de otro centro.

## 2. Qué cambia para quien usa el sistema

**Para el personal de cada gimnasio: prácticamente nada.** Se trabaja igual que
hoy: mismo inicio de sesión, mismas pantallas, mismos flujos. Los cambios son
internos (cada petición sabe a qué centro pertenece y filtra automáticamente).

**Lo nuevo son tres cosas, todas del lado de la administración del SaaS:**

1. **Modo superadministrador**: pantallas nuevas para dar de alta gimnasios,
   activarlos/desactivarlos y gestionar usuarios de todos los centros.
2. **Acceso de soporte con auditoría**: el superadministrador puede entrar a un
   centro para dar ayuda remota, con un aviso visible en pantalla y registro de
   todas sus acciones (quién, cuándo, en qué centro).
3. **Aprobación de turnos atípicos**: si alguien abre o cierra caja fuera del
   horario del gimnasio, queda una solicitud pendiente que el administrador del
   centro aprueba o rechaza después. La operación no se detiene.

## 3. Qué NO cambia

- Las pantallas y flujos actuales de cada gimnasio (socios, check-in, ventas,
  reportes, configuración…) se conservan.
- Los datos actuales del gimnasio: se migran íntegros a la nueva estructura
  mediante un proceso supervisado de un solo paso, sobre una copia de respaldo
  (nunca sobre la base en producción).
- Los costos de operación: se sigue usando una sola aplicación y una sola base
  de datos; no hay infraestructura nueva por cliente.

## 4. Decisiones ya tomadas (requieren solo confirmación)

| # | Decisión | Por qué |
| --- | --- | --- |
| 1 | Una sola base de datos compartida, con columna de centro en cada tabla operativa | Menor costo y operación simple; el aislamiento se garantiza por software |
| 2 | El correo electrónico es el identificador de usuario, único en todo el sistema | El plan original lo pedía; además sirve para notificaciones |
| 3 | Los socios (teléfono/correo) se repiten **entre** centros, no dentro de uno | La misma persona puede ser socia de varios gimnasios |
| 4 | El centro viaja dentro del token de sesión, jamás lo envía la pantalla | No es manipulable desde el navegador: una sola fuente de verdad |
| 5 | El superadministrador y el administrador de centro son cuentas separadas | Toda acción queda auditada por separado |
| 6 | Renombrar el rol interno "User" a "Staff" | El plan original lo marcaba pendiente |
| 7 | Alta de cada centro crea automáticamente: administrador del centro, usuario de recepción, socios genéricos y configuraciones | El centro queda operativo desde el minuto uno |
| 8 | Planes/paquetes de funcionalidades por centro: **fase posterior** | Aún no está definido el modelo comercial; los centros nacen con todo habilitado |
| 9 | Sucursales: **fase posterior** | Hoy ningún dato necesita ligarse a sucursales |

## 5. Preguntas que necesitan su respuesta

Estas sí requieren decisión del cliente antes de implementar; cada una incluye
nuestra recomendación:

| # | Pregunta | Nuestra recomendación |
| --- | --- | --- |
| A | Si un turno queda pendiente de aprobación, ¿la caja sigue operando? | **Sí, sigue operando**: la aprobación es un control posterior, no un candado que detenga la venta |
| B | ¿Quién puede editar o desactivar al administrador de un centro? | **Solo el superadministrador**: máxima protección del rol crítico del centro |
| C | ¿Qué avisos debe recibir el administrador del centro y por qué medio? | En esta fase, avisos dentro de la pantalla; correo electrónico en la fase de planes |
| D | ¿Qué pasa con los datos de un gimnasio que se da de baja definitivamente? | Proponemos definirlo en conjunto: periodo de gracia + exportación de datos antes del borrado físico |

Preguntas menores (nombre del modo de operación, retención del registro de
auditoría, zona horaria para horarios) están listadas en el anexo de preguntas
abiertas; ninguna bloquea el inicio.

## 6. Plan por fases

1. **Fundaciones** — tablas de centro y auditoría, columna de centro en las
   ~33 tablas operativas, sesión con centro incluido, filtrado automático en
   todos los servicios.
2. **Modo superadministrador** — API y pantallas de centros y usuarios, acceso
   de soporte con auditoría.
3. **Ajustes funcionales** — aprobación de turnos fuera de horario.
4. **Migración del gimnasio actual** — proceso de un solo paso sobre respaldo,
  con verificación de conteos y prueba de humo.
5. **Fase posterior** (no incluida aquí): planes de funcionalidades por centro,
   sucursales, borrado físico automatizado.

## 7. Riesgos principales y mitigación

- **Fuga de datos entre centros** (un servicio que olvide filtrar): mitigado con
  revisión de código y pruebas de aislamiento centro-a-centro en servicios clave.
- **Migración de datos históricos**: se ejecuta sobre un respaldo restaurado; si
  algo falla se restaura y se reintenta desde cero. Verificación manual con
  conteos por tabla antes/después (sin pruebas automatizadas, por decisión del
  plan original).
- **Decisiones abiertas** (sección 5): bloquean solo su tema específico, no el
  arranque de la fase 1.

---

## Anexos técnicos

| Documento | Contenido |
| --- | --- |
| [ADRs](./adr/) (9) | Decisiones de arquitectura con contexto, alternativas y consecuencias |
| [Stories](./stories/) (14) | Trabajo desglosado con criterios de aceptación y dependencias |
| [Preguntas y respuestas](./preguntas-y-respuestas.md) | Todas las dudas abiertas y el histórico de respuestas |
| [Esquema propuesto](./schema-propuesta.sql) | Base de datos resultante, consolidada y anotada |
| [Diagramas](./diagramas.md) | Componentes y flujos (login, soporte, turnos, migración) |
