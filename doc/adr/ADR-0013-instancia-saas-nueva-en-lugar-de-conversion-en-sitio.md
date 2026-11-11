# ADR-0013: Instancia SaaS nueva en lugar de convertir las instalaciones existentes

**Estado**: Aceptada · **Fecha**: 2026-11-05
**Origen**: entrevista `sdd-grill-idea`, 7 rondas, slug `migracion-instancia-limpia` · spec pendiente

## Contexto

Hoy operan **dos instalaciones independientes en producción**: FitRoom y Fussion. Cada
una es mono-gimnasio, se distingue por la variable `GYM_BRAND` (ADR-0012) y tiene su
propio par de despliegues — verificado en el repo `gym`: `deploy-backend.yml`,
`deploy-backend-fussion.yml`, `deploy-frontend.yml`, `deploy-frontend-fussion.yml`.

Dos ADRs aceptadas se contradicen en este punto:

- **ADR-0001** decidió esquema compartido con `center_id` y dejó como consecuencia
  positiva "un solo despliegue y una sola base".
- **ADR-0007** decidió un script one-shot sobre un backup restaurado cuya base de
  trabajo "se convierte en la nueva base del centro" — es decir, **una base por
  centro**, que es lo contrario.

La presión que fuerza la decisión: el equipo espera más gimnasios. Convertir cada
instalación en sitio significa repetir la conversión a SaaS por cada gimnasio que
llegue con su propia instalación, y aun así terminar con N bases mono-tenant. El
trabajo se pagaría otra vez cada vez.

## Decisión

Se levanta una **instancia SaaS nativa** completa y vacía — base MySQL nueva, backend,
frontend y dominio nuevos — que nace con el esquema multi-centro completo. Las dos
instalaciones existentes **no se convierten**: sus datos se migran a la instancia nueva,
cada gimnasio como un centro con una sucursal (una sola dirección física cada uno).

1. **Secuencial**, un gimnasio a la vez. No se opera en dos mundos.
2. Al terminar la migración de un gimnasio, su instalación original pasa a
   **solo-lectura** (instancia congelada). El cliente ya no puede escribir ahí. Esto
   elimina las copias delta y la reconciliación.
3. La instancia congelada se mantiene **una o dos semanas a lo mucho**; DevOps decide el
   apagado. Su dump final va a S3 Glacier por **un año** y se borra por lifecycle; el
   cliente ya lo sabe.
4. **Sin rollback.** La instancia congelada en solo-lectura es la red: la verdad
   histórica sigue siendo legible, así que un error se corrige hacia adelante.
5. El código es el **mismo repo `gym`**, desplegado como un ambiente más. Las
   instalaciones actuales quedan congeladas y, si hace falta un parche, se maneja con
   release branches.
6. La base nueva arranca con la **cadena completa de 102 migraciones Flyway**, no con un
   baseline colapsado.
7. Los gimnasios nuevos se registran directamente en la instancia SaaS; no pasan por
   migración.

## Alternativas consideradas

- **Convertir cada instalación en sitio** (lo que implicaba ADR-0007): obliga a correr
  la conversión a SaaS sobre cada base de producción existente, y a repetir ese trabajo
  por cada gimnasio futuro que llegue con instalación propia. Además deja N bases
  mono-tenant, que contradice el esquema compartido de ADR-0001 y multiplica despliegues,
  respaldos y herramientas de reporte. Y la primera conversión ocurriría sobre datos
  vivos del cliente sin un destino limpio contra el que comparar.
- **Baseline Flyway colapsado para la base nueva**: historia de esquema más corta y
  limpia. Rechazada porque tres de las 102 migraciones son **Java**
  (`V202403121643__load_cities_from_csv`, `V202403121649__import_colonias_veracruz`,
  `V202403121688__remove_invalid_fingerprint_templates`) y los catálogos geográficos
  compartidos — regla 3 de ADR-0001 — tendrían que sembrarse por otro camino. Arrastrar
  las 102 cuesta casi nada; re-ingeniar la siembra sí cuesta.
- **Operación en paralelo durante la validación**: nunca estuvo en juego de verdad. El
  cliente tendría que registrar en dos lados, lo que se descartó como inviable para él.
  Es justamente esa inviabilidad la que hace innecesarias las copias delta.
- **Rollback a la instancia congelada después del corte**: se evaluó y se descartó.
  Revertir implica descartar todo lo que el gimnasio capturó en la instancia nueva desde
  que abrió, y reconciliarlo a mano. Se acepta la instancia congelada como sustituto.

## Consecuencias

**Positivas**

- Un despliegue y una base, alineado con ADR-0001. Un tercer gimnasio cuesta una corrida
  de migración, no un proyecto de conversión.
- Las instalaciones existentes nunca corren cambios de esquema riesgosos: se congelan, no
  se modifican.

**Costos aceptados a sabiendas**

- **Sin rollback.** En el momento en que el gimnasio abre sobre la instancia nueva, el
  corte es irreversible.
- **La instancia nueva no nace vacía.** Correr la cadena de Flyway en una instancia
  limpia deja filas que no pertenecen a ningún centro:
  `V202403121631__insert_checkin_gym.sql` siembra un usuario **`CHECKIN_GYM`**, y los
  socios internos ("Público en General", "Visita") también llegan sembrados, todos con
  `center_id = NULL`. Dos consecuencias verificadas:

  1. Como P-01 dejó `users.username` único global y **toda** instalación trae
     `CHECKIN_GYM`, la colisión ocurre con el **primer** gimnasio migrado, no con el
     segundo. ADR-0015 la resuelve aplicando el patrón de P-04.
  2. Esas filas no tienen protección contra duplicados: `center_id = NULL` significa
     SUPERADMIN según ADR-0003, y un índice UNIQUE con NULL en el tuple admite filas
     duplicadas sin límite.

  **Qué hacer con ellas está abierto (P-15)**: adoptarlas en el primer centro migrado,
  borrarlas de la instancia nueva antes de migrar, o que las migraciones dejen de
  sembrarlas cuando el modelo de tenant ya existe.
- **El gimnasio abre antes de que el negocio firme.** DevOps corre la migración de noche,
  solo, y firma lo técnico; las dos direcciones validan en los días siguientes contra la
  instancia congelada. El primer socio que hace check-in ya consumó el corte. Los
  detalles del procedimiento se afinan antes de la migración real (P-16).
- **El trabajo multi-tenant pendiente viaja igual.** Una instancia nueva no arregla el
  riesgo abierto de ventas, inventario, compras y artículos sin filtro por centro: ese
  código llega idéntico a la instancia nueva.
- **Disparador para reabrir**: la aparición de un tercer origen cuyo dump difiera de los
  dos conocidos.

## Nota sobre la numeración de migraciones (2026-11-11)

Las migraciones SaaS **se renumeraron** cuando entraron tres de `main` por delante. La
correspondencia, para poder seguir las referencias de este documento y de las stories:

| Antes | Ahora | Migración |
| --- | --- | --- |
| V696 | **V699** | `create_centers_table` |
| V697 | **V700** | `add_center_id_to_users_table` |
| V698 | **V701** | `create_audit_log_table` |
| V699 | **V702** | `add_center_id_to_other_tables` |
| V700 | **V703** | `replace_unique_key_to_cell_phone_and_email_columns` |
| V701 | **V704** | `replace_admin_to_center_admin` |
| — | **V705** | `create_branches_and_add_branch_id` (ST-015) |
| — | **V706** | `replace_member_unique_constraints_with_branch` (ST-016) |

Renumerar fue gratis porque nada está desplegado. La decisión de conservar la cadena
completa en lugar de colapsarla a un baseline se sostiene: las 104 migraciones SQL
construyen el esquema sin intervención, y las 3 **Java** son el único hueco — siembran
catálogos geográficos, que hay que sembrar aparte.

## Puerta

**Puerta de un solo sentido.** Una vez que un gimnasio opera sobre la instancia nueva y
su origen quedó en solo-lectura, volver atrás significa descartar datos de operación
real. La instancia congelada limita el daño — la historia sigue legible — pero no vuelve
la decisión reversible. Las once verificaciones de ADR-0015 y la validación en paralelo
existen precisamente porque esta puerta no tiene regreso.
