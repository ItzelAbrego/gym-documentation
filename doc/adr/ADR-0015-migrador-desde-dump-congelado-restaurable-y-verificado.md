# ADR-0015: Migrador en Python desde dump congelado, restaurable y verificado por chequeos bloqueantes

**Estado**: Aceptada · **Fecha**: 2026-11-05 · **Actualizada**: 2026-11-11
**Origen**: entrevista `sdd-grill-idea`, 7 rondas, slug `migracion-instancia-limpia`
**Reemplaza a**: [ADR-0007](ADR-0007-migracion-de-datos.md) (que se conserva como histórico)
**Implementación**: `gym/gym-migrator` (prototipo) · PR ItzelAbrego/gym#531

## Contexto

ADR-0013 decidió el *dónde* van los datos. Falta el *cómo llegan*. ADR-0007 ya
había respondido eso, pero cuatro de sus premisas dejaron de ser ciertas:

| Premisa de ADR-0007 | Por qué ya no aplica |
| --- | --- |
| Flyway corre primero sobre la base de trabajo y el script le agrega `center_id` | El destino ya nace con el esquema SaaS completo; el migrador transforma **entre dos esquemas**, no actualiza columnas en su lugar |
| La base de trabajo se convierte en la base del centro | ADR-0013: hay una sola base compartida y el destino ya existe |
| "Sin pruebas automatizadas — decisión explícita del plan de origen" | Se revierte: "ahora mismo sí necesitamos hacer todas las pruebas posibles para validar que todo se migre bien" |
| Script one-shot desechable | Es pieza mantenida: un gimnasio con instalación propia podría querer migrar a SaaS después, "es difícil que suceda pero no imposible" |

Una restricción dura la fija el negocio: **las fechas tienen que llegar tal
cual**. `created_at` y `register_timestamp` son parte de lo migrado, no datos que
el destino pueda regenerar.

## Decisión

> **CORRECCIÓN (2026-11-11)**: la primera versión de este documento afirmaba que
> el migrador preserva los `id` además de las fechas. **Eso es imposible y se
> retira.** `members.id` y `users.id` son `INT AUTO_INCREMENT` con PK simple, y
> las dos instalaciones traen un socio con `id = 1`; en una base compartida
> colisionan. Lo que se preserva —y era el requisito real— son **las fechas**.
> Los IDs se remapean y la correspondencia se archiva (punto 11).

1. **Origen: dump congelado**, no lectura directa de la base de producción. Se
   toma el dump en la ventana de corte, el origen pasa a solo-lectura y a partir
   de ahí el dump no cambia.
2. **SQL directo**, no alta por API. Es la única forma de que las fechas lleguen
   sin pasar por una capa que las convierta.
3. **Python**, en un módulo aislado dentro del repo `gym`, con su propio
   contenedor y sin tocar el build de Maven. Java queda excluido por un riesgo
   concreto: JPA más zonas horarias puede alterar fechas en silencio.
4. **Restaurable, no idempotente.** Si una corrida falla, se restaura el destino
   limpio y se re-corre desde el mismo dump congelado. Sin reanudación por tabla.
   El migrador se **niega** a escribir sobre un destino que ya tiene ese centro.
5. **El migrador crea el centro y su sucursal principal**, para conocer de
   inmediato los IDs que va a usar. Los pasos 1 y 2 de ADR-0007 siguen vigentes,
   y el paso 2 ya es posible: `V202403121705` creó `branches`. El gimnasio
   migrado opera en una sola dirección física, así que llega como un centro con
   una sucursal.
6. **Toda fila migrada lleva `center_id` y `branch_id`.** No es cosmético: desde
   `V202403121706` las unique keys de socio incluyen `branch_id`, y en MySQL un
   índice UNIQUE cuyo tuple contiene NULL admite filas duplicadas sin límite. Una
   fila sin sucursal no fallaría — se quedaría **sin ninguna protección contra
   duplicados**, y la base no se queja.
7. **Fidelidad de fechas con mecanismo explícito**: la zona horaria de sesión se
   fija idéntica en las dos conexiones. MySQL guarda `TIMESTAMP` en UTC y lo
   convierte con la tz de sesión al leer y al escribir, así que con la misma tz
   en ambos lados el round-trip es exacto; `DATETIME` no se convierte nunca. La
   huella de verificación se calcula **en SQL**, no en Python, para que el propio
   driver no pueda enmascarar el error que se busca, con
   `BIT_XOR(CRC32(...))`: independiente del orden y sin truncamiento, a
   diferencia de `MD5(GROUP_CONCAT(...))`, que se cortaría en silencio al pasar
   `group_concat_max_len`.
8. **Chequeos bloqueantes**, con la severidad como **dato configurable** —no una
   constante en el código— admitiendo dos granularidades: el chequeo completo o
   una tabla/columna concreta.

   Implementados y verificados corriendo:

   | id | Qué compara |
   | --- | --- |
   | `C01-row-counts` | filas por tabla: origen, destino del centro y mapa de IDs |
   | `C03-dates` | huella, conteo, mínimo y máximo de cada columna de fecha |
   | `C07a-center-scoping` | toda fila **que esa corrida escribió** lleva `center_id` |
   | `C07b-catalogs` | `city_id` y `colonia_id` resuelven contra los catálogos compartidos |
   | `C07c-branch-scoping` | toda fila migrada lleva `branch_id`; se excluyen los roles de ámbito centro |
   | `C07d-branch-center` | todo `branch_id` pertenece al centro de la propia fila |
   | `C08-unique-collapse` | teléfono y correo de socio siguen únicos dentro de cada sucursal |
   | `C11-usernames` | colisiones de `users.username`, resueltas o rechazadas, **antes** de escribir |
   | `C12-orphan-seed-rows` | filas que la cadena de Flyway sembró y no pertenecen a ningún centro |

   Pendientes: sumas de dinero, suscripciones vigentes, cortesías, **stock por
   sucursal (bloqueado por P-14)**, mapeo de roles verificado en destino, y fotos.

9. **Resolución de colisiones de `username`, parcialmente cerrada.** Las de
   usuario quiosco se renombran aplicando P-04 (`CHECKIN_<slug>`), que ya había
   decidido ese patrón: no se inventa política. Cualquier otra colisión —un
   correo de login de una persona— se **rechaza y la corrida aborta antes de
   escribir**, porque renombrar la identidad de alguien no le toca decidirlo al
   migrador.
10. **Dry-run = corrida completa contra una base destino desechable**, con todo
    escrito y los chequeos ejecutados. La corrida real es exactamente la misma,
    apuntando a la base de la instancia SaaS. Una corrida que no escribe no puede
    comparar conteos, porque no hay destino que comparar.
11. **La evidencia se archiva por centro**: reporte y mapa de IDs en
    `out/<slug-del-centro>/`. Se firman después de que el gimnasio abrió.
12. **El banco de pruebas construye sus esquemas con las migraciones reales**: el
    origen corre Flyway hasta `-target=202403121698` (la última pre-SaaS) y el
    destino corre todas. No se mantiene una copia del esquema a mano. Tiene que
    replicar dos ajustes de `application.yml` o construye un esquema que la app
    jamás produciría: `FLYWAY_TABLE=schema_version` (la app usa el nombre legado,
    y `V202403121681` lee su fecha de corte de esa tabla) y
    `FLYWAY_BASELINE_ON_MIGRATE=true`.
13. **Validación por doble migración**: migrar el mismo gimnasio dos veces como
    dos centros y comparar las copias. Prueba tres propiedades que ningún chequeo
    individual cubre — determinismo, aislamiento entre centros, e independencia
    de IDs. La comparación excluye `id`, `center_id`, `branch_id` y
    `users.username`, cada una con su razón registrada como dato.
14. **Lo corre DevOps**, de noche, sin presencia del gimnasio.

## Alternativas consideradas

- **Alta por API en lugar de SQL**: hereda gratis todas las validaciones que hoy
  viven en los servicios Java — unicidad de socio, reglas de turno, consistencia
  de stock. Pierde por un requisito duro: no puede preservar `created_at`, y la
  historia tiene que llegar tal cual.
- **Java/Spring reusando las entidades JPA**: daría las validaciones y viviría
  nativo en el repo. Rechazada por la razón concreta que dio el developer: JPA
  más zonas horarias es exactamente el mecanismo que podría correr las fechas sin
  avisar. "Aunque podríamos reusar, no lo recomiendo."
- **Migrador idempotente**: re-correr sobre un destino parcialmente escrito
  exigiría persistir claves de correspondencia origen→destino y escrituras
  condicionales en cada tabla. Se pidió al principio y se descartó al elegir
  "restaurable": con el snapshot disponible, la idempotencia no compra nada que
  no se tenga ya.
- **Lectura directa de la base de producción**: ahorra el paso del dump, pero
  expone la base viva del cliente a una conexión del migrador y no deja un
  artefacto congelado que re-consumir en cada reintento — que es justo lo que la
  estrategia restaurable necesita.
- **Dry-run que no escribe nada**: incoherente, y se descartó por eso. Los
  chequeos comparan origen contra destino; sin escribir no hay destino que
  comparar.
- **Mantener a mano una copia del esquema destino** (lo que hizo la primera
  versión del banco de pruebas): más simple de arrancar, sin dependencia de la
  carpeta de migraciones. Rechazada con evidencia: esa copia quedó mal de **tres
  formas en una semana** —la renumeración de las migraciones SaaS, la llegada de
  `branches`, y el cambio de las unique keys de socio— y **ninguna hizo ruido**.
  El costo de leer las migraciones reales es que las tres migraciones **Java** no
  corren y hay que sembrar `colonias` aparte.
- **Renombrar automáticamente cualquier username colisionado** con un sufijo del
  centro: resolvería todas las colisiones sin intervención. Rechazada para los
  correos de login: cambiar con qué credencial entra una persona no es una
  decisión del migrador, y el fallo aparecería cuando esa persona no pudiera
  iniciar sesión.
- **Comparación de reportes de negocio como chequeo bloqueante**: propuesta y
  **diferida** para revisar con el equipo. Es el único chequeo que validaría
  semántica y no estructura. Costo aceptado: el conjunto bloqueante verifica que
  los datos *llegaron*, no que el sistema nuevo *los interpreta igual*.
- **Lista de chequeos fija en código**, sin severidad configurable: más simple.
  Rechazada porque la herramienta se mantiene y la severidad va a querer
  ajustarse — y de hecho ya se ajustó, para `C12`.

## Consecuencias

**Positivas**

- Cada reintento parte del mismo artefacto congelado; nada depende del estado de
  un destino a medio escribir.
- Las fechas llegan intactas, que era el requisito explícito.
- El banco de pruebas no puede quedar desfasado del esquema sin que se note.
- El dry-run ejerce el mismo camino de código que la corrida real.

**Costos aceptados a sabiendas**

- **SQL directo se salta todas las invariantes que sólo viven en los servicios
  Java.** Los chequeos son la única red. Si una regla de negocio no está
  expresada como constraint en la base ni como chequeo en la lista, el migrador
  puede violarla sin que nadie se entere.
- **Python dentro de un repo Java** es un injerto que alguien tiene que mantener.
- **Los dumps reales traen datos personales** — teléfonos, correos y fotos de
  socios. Las pruebas se quedan en local hasta decidir cómo se manejan en CI.
- **Un tercer origen desconocido no tiene comportamiento definido.**
- **El mismo gimnasio no se puede migrar dos veces a la misma instancia** con los
  mismos correos de login, porque `users.username` es único global (P-01). Eso
  **no es un defecto**: es lo que evita que un gimnasio se migre por accidente
  dos veces, lo que duplicaría a todos sus socios.
- **`ON UPDATE CURRENT_TIMESTAMP` destruye la fidelidad de fechas en silencio.**
  `members.updated_at` lleva esa cláusula, así que **cualquier `UPDATE` sobre una
  fila ya migrada le reescribe la fecha de modificación con la hora actual**. Se
  comprobó: al mover una sola fecha a mano, el chequeo falló en **dos** columnas
  —la tocada y `updated_at`, que se movió sola—. Como ADR-0013 no contempla
  rollback, esa pérdida no se recupera. **Si hay que corregir, se restaura y se
  re-corre; no se parchea en caliente.** Hay que auditar todas las columnas con
  esa cláusula al extender el migrador al resto de los dominios.
- ADR-0007 conserva su archivo como histórico; este registro y ADR-0013 la
  reemplazan.

## Puerta

**Dos sentidos para las decisiones de implementación** — lenguaje, contenedor,
lista de chequeos: todas reversibles con un diff mientras la herramienta no ha
corrido ni una vez en producción.

**Un solo sentido para los datos escritos.** En cuanto un gimnasio opera sobre los
datos migrados, corregir un error de transformación es corrección hacia adelante,
porque ADR-0013 aceptó no tener rollback. Eso es lo que sube la barra de los
chequeos: son la última oportunidad de detectar el error mientras todavía es
barato.
