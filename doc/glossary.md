# Glosario

Vocabulario acordado en este proyecto. Cada entrada registra **el significado que el
equipo acordó en conversación**, no el del diccionario ni el de la industria en
general. Donde un término se usa aquí más estrecho que en otros lados, el sentido
estrecho es el que vale.

Se escribe al primer uso del término, durante la conversación, no en una pasada de
limpieza al final.

---

## instancia SaaS nativa

El despliegue nuevo y vacío que nace ya con el esquema multi-centro completo
(`centers`, `branches`, `center_id` y `branch_id` en su lugar) y al que se mudan los
gimnasios existentes. "Nativa" califica a la base de datos y al ambiente, no al
código: es el mismo repositorio `gym`, desplegado como un ambiente más, no una
reescritura. No confundir con las instalaciones actuales de FitRoom y Fussion, que
nacieron mono-gimnasio y a las que **no** se les corre la conversión a SaaS.

First used: 2026-11-05

## instancia congelada

Una instalación mono-gimnasio original (FitRoom o Fussion) después de que su
gimnasio ya opera en la instancia SaaS nativa: sigue encendida y consultable, pero el
cliente no puede escribir en ella. Se mantiene así una o dos semanas como máximo y
DevOps decide el apagado. No es un respaldo ni un ambiente de pruebas: es la fuente de
verdad histórica contra la que el negocio valida lo migrado, y es la única red que
sustituye al rollback.

First used: 2026-11-05

## migrador

La herramienta que lee un dump congelado de una instalación mono-gimnasio y escribe
sus datos en la instancia SaaS nativa como un centro con una sucursal. Escribe SQL
directo, no pasa por la API ni por las entidades JPA, precisamente para preservar
`id`, `created_at` y `register_timestamp` tal cual. Es pieza mantenida, no script
desechable, aunque hoy sólo se ejercite contra dos orígenes conocidos. No confundir
con las migraciones de Flyway, que cambian el **esquema**; el migrador mueve **datos**
entre dos esquemas distintos.

First used: 2026-11-05

## dump congelado

El respaldo SQL que se toma de una instalación mono-gimnasio en la ventana de corte y
que a partir de ese momento ya no cambia, porque el cliente perdió la escritura sobre
el origen. Es el artefacto que el migrador consume y el que se vuelve a consumir en
cada reintento, lo que hace posible la estrategia restaurable. No es el dump de
pruebas: los de pruebas son copias anteriores usadas en local; el congelado es el
único del que sale la migración real.

First used: 2026-11-05

## dry-run de migración

Una corrida completa del migrador contra una base destino **desechable** — el
contenedor del docker-compose de pruebas — con todo escrito y los chequeos ejecutados.
No es una simulación que no escribe: una corrida que no escribe no puede comparar
conteos ni sumas contra el destino, y por eso se descartó esa lectura del término. La
corrida real es exactamente la misma, apuntando a la base de la instancia SaaS.

First used: 2026-11-05

## ventana de corte

Las horas nocturnas en que el gimnasio está cerrado y se ejecuta la migración de ese
gimnasio: se toma el dump congelado, el origen queda en solo-lectura, corre el
migrador y corren los chequeos. Son más de dos horas disponibles. Dentro de la ventana
nadie captura datos en ningún sistema, lo que es lo que elimina la necesidad de copias
delta o reconciliación.

First used: 2026-11-05

## chequeo bloqueante

Una verificación de la migración cuyo fallo impide declarar la migración aceptada. Al
inicio los once chequeos de integridad son todos bloqueantes, y la severidad es un
dato configurable de la herramienta — no una constante en el código — para poder
degradar alguno a informativo con el tiempo. La comparación de reportes de negocio
quedó explícitamente **fuera** del conjunto bloqueante inicial.

First used: 2026-11-05

## reporte de migración

La salida que el migrador produce al terminar: el resultado de cada chequeo con su
severidad. Se archiva junto al dump congelado, de modo que la evidencia y los datos de
origen viven en el mismo lugar. Es lo que firman la dirección del equipo y la dirección
del gimnasio, y lo firman **después** de que el gimnasio abrió, no como condición para
abrir.

First used: 2026-11-05

## socio de sucursal

Desde `V202403121706`, la ficha de un socio pertenece a **una sucursal**, no al
centro: su teléfono y su correo son únicos dentro de `(center_id, branch_id)`. La
misma persona que entrena en dos sucursales del mismo centro necesita dos fichas.
No confundir con lo que decía la regla 4 de ADR-0010, que ponía al socio a nivel
centro con una sola ficha para todas sus sucursales; esa regla quedó revertida
(N-11) y el término existe para dejar claro cuál de los dos modelos está vigente.

First used: 2026-11-11

## filas sembradas sin centro

Las filas que la propia cadena de migraciones de Flyway inserta en cualquier
instalación y que quedan con `center_id = NULL` en una instancia SaaS nueva: el
usuario quiosco `CHECKIN_GYM` y los socios internos. No son datos migrados ni
basura de pruebas: son el residuo del sistema mono-gimnasio dentro del modelo
multi-tenant, y por eso ocupan el `username` único global antes de que se migre el
primer gimnasio. Qué hacer con ellas es P-15.

First used: 2026-11-11

## doble migración

Migrar el mismo gimnasio dos veces como dos centros, para comparar las copias y
verificar determinismo y aislamiento. Como técnica de validación es deliberada;
como accidente operativo es lo que la unicidad global de `users.username` impide,
porque duplicaría a todos los socios del gimnasio. Las dos acepciones conviven: la
validación necesita que la segunda copia tenga identidades de login distintas,
justamente porque el accidente está bloqueado.

First used: 2026-11-11

## evidencia de migración

El reporte de chequeos más el mapa de correspondencia de IDs de una corrida,
archivados en una carpeta propia del centro. Es lo que firman la dirección del
equipo y la dirección del gimnasio, y lo que permite reconstruir qué fila del
origen es cuál en el destino. No es un log: un log se puede rotar, esto no, porque
sin él la correspondencia de IDs se pierde para siempre.

First used: 2026-11-11
