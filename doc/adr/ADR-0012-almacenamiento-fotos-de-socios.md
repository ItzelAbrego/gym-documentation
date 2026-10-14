---
id: ADR-0012
tipo: adr
titulo: Almacenamiento de fotos de socios en S3 con URLs firmadas
estado: propuesta
fecha: 2026-10-13
---

# ADR-0012: Almacenamiento de fotos de socios en S3 con URLs firmadas

**Estado**: Propuesta · **Fecha**: 2026-10-13

## Contexto

El catálogo de socios tiene una columna "Acciones" que agrupa los movimientos disponibles sobre el perfil de un socio. Hoy no existe forma de asociar una fotografía al socio. El [ticket de ClickUp 86akm8wag](https://app.clickup.com/t/86akm8wag) pide incorporar una opción nueva en esa columna que permita cargar la foto mediante un modal y, posteriormente, visualizarla desde el mismo apartado.

La fotografía es contenido de usuario que debe sobrevivir a los redespliegues y a la rotación de contenedores. La decisión central es dónde se almacena el archivo y cómo lo sirve el frontend, sin perder archivos ni dejar el binario acoplado al ciclo de vida del contenedor.

Hechos relevantes del proyecto que condicionan la decisión:

- El despliegue es de una sola marca por instalación. La marca se configura con `gym.brand` (variable de entorno `GYM_BRAND`) y hoy toma los valores `fitroom` o `fussion`. El backend es dueño de la marca y `BrandingService.activeBrand()` ya expone el valor normalizado en minúsculas y sin espacios.
- `gym-api` es Spring Boot sobre MySQL con migraciones Flyway en `db/migration`, con la convención `V{version}__descripcion.sql`.
- `gym-api` no tiene todavía ninguna dependencia de almacenamiento de objetos ni cliente de AWS; habría que incorporarla.
- Existe un precedente directo en la organización: UTEM-API ya implementa fotos de perfil con S3 y URLs firmadas, de modo que el patrón está probado.
- El comentario del ticket deja pendiente una validación: acordar con Luis Juárez el mecanismo concreto de carga de archivos antes de implementar.

La creación y el aprovisionamiento del bucket se consideran una tarea aparte, fuera del alcance de este registro.

## Decisión propuesta

Almacenar las fotos de socios en un bucket S3 (o un almacenamiento compatible con S3) y servirlas al frontend mediante URLs firmadas de corta duración. La subida pasa por el backend, que recibe el archivo como `multipart/form-data` y lo escribe en S3. La visualización se resuelve con una URL firmada de tipo GET que el navegador carga directamente desde S3.

La clave del objeto es determinística y lleva como prefijo la marca activa:

```
{marca}/members/{idSocio}/photo

# ejemplos
fitroom/members/42/photo
fussion/members/42/photo
```

donde `{marca}` proviene de `BrandingService.activeBrand()` (`fitroom` o `fussion`). Al subir una foto nueva se sobrescribe el objeto existente en esa misma clave. No se implementa borrado de archivos: subir reemplaza y nada más, en línea con el requisito de negocio.

Para que la clave siga siendo determinística y el reemplazo sobrescriba de verdad, la clave no lleva extensión. El tipo de contenido (`image/png`, `image/jpeg`, `image/gif`) se guarda como metadato del objeto en la escritura y se respeta al generar la URL firmada. Así, cambiar de formato nunca deja un objeto huérfano en el bucket.

Esta decisión permanece en estado **Propuesta** hasta confirmar con Luis Juárez el proveedor y el bucket a utilizar.

## Patrón de referencia (UTEM-API)

Se reutiliza el patrón ya verificado en UTEM-API:

- La subida pasa por el backend: el navegador envía `multipart/form-data` y el backend transmite el contenido a S3 mediante `S3Client.putObject`. No se usan URLs firmadas de subida (PUT).
- La visualización usa una URL firmada de tipo GET con expiración de quince minutos, devuelta como `text/plain`; el frontend la carga directamente desde S3 en una etiqueta `<img>`.
- La configuración de credenciales es adaptable al entorno: credenciales explícitas en local o LocalStack mediante `StaticCredentialsProvider`, y la cadena por defecto (`DefaultCredentialsProvider`, rol de IAM) en producción. Admite sobrescribir el endpoint y el acceso por ruta para almacenamientos compatibles con S3.
- La validación limita el tipo de contenido a imágenes y el tamaño máximo mediante `spring.servlet.multipart`.

## Alternativas consideradas

### Volúmenes de Docker con respaldo desde la interfaz de Dokploy

El archivo vive en un volumen montado en el host y los respaldos se realizan desde la interfaz de Dokploy. Se descarta por el riesgo real de pérdida de datos ya observado: si el respaldo falla o el volumen se corrompe, las fotos se pierden. Además, acopla el ciclo de vida del archivo al del contenedor, no escala a varias instancias, respalda el binario y su referencia en base de datos por caminos distintos y obliga a una restauración manual poco reproducible.

### S3 con clave UUID y borrado del objeto anterior (patrón UTEM literal)

Replicar UTEM-API al pie de la letra: cada carga genera una clave UUID nueva, se persiste su metadato en una tabla `files` y, al reemplazar, se borra el objeto anterior. Se descarta porque contradice el requisito de no implementar borrado: o se borra el objeto viejo, o se acumulan objetos huérfanos indefinidamente. También añade más superficie de la necesaria para este caso (tabla `files`, entidad de relación y flujo transaccional de reemplazo).

## Consecuencias

- Las fotos sobreviven a los redespliegues y a la rotación de contenedores sin depender de respaldos manuales.
- Los archivos de cada marca quedan aislados por el prefijo de la clave, alineado con el modelo de una sola marca por instalación.
- Se reduce el código y el esquema respecto del patrón completo de UTEM: la clave es derivable de la marca y el identificador del socio, sin tabla `files`.
- Las fotos se sirven de forma privada: el bucket no es público y las URLs expiran.
- Se incorpora una dependencia nueva (AWS SDK v2: `s3` y `s3-presigner`) y la gestión de credenciales o de un rol de IAM.
- Al no borrar, un socio eliminado conserva su foto en el bucket, lo que se acepta por negocio.

## Implementación esperada

La implementación concreta se detalla en el ticket; se resume aquí para orientar.

En `gym-api`:

- Dependencias de AWS SDK v2 (`s3` y `s3-presigner`).
- Una configuración de AWS con los beans de cliente y de firmante (`S3Client` y `S3Presigner`), portada de UTEM-API.
- Un servicio de foto de socio con una operación para subir (valida y escribe en la clave `{marca}/members/{idSocio}/photo`, sobrescribiendo) y otra para generar la URL firmada de visualización (quince minutos, o respuesta vacía si no hay foto).
- Endpoints `POST /members/{id}/photo` (multipart) y `GET /members/{id}/photo` (texto plano con la URL), protegidos con la autorización correspondiente.
- Opcionalmente, una bandera `has_photo` en la tabla de socios mediante una migración Flyway, para evitar una consulta a S3 por cada fila del catálogo.

En `gym-web`:

- Una acción "Imagen de usuario" en la columna "Acciones" del catálogo de socios.
- Un modal de carga (Angular Material) con selección de archivo y vista previa.
- Un servicio con las operaciones de subida y de obtención de la URL para alimentar la etiqueta `<img>`.

## Preguntas abiertas

- Confirmar con Luis Juárez si se usa AWS S3 o un almacenamiento compatible con S3 (R2, MinIO, Spaces o B2) y si ya existe un bucket y credenciales aprovisionados por entorno. Es la validación pendiente del comentario del ticket. La creación del bucket es una tarea separada.
- Decidir si se guarda la bandera `has_photo` en base de datos o se consulta siempre a S3 al renderizar el catálogo.
- Acordar con negocio el tamaño máximo y los formatos admitidos (por ejemplo, solo `jpg` y `png`, hasta 5 MB).

## Plan de trabajo (subtareas)

El trabajo se divide en cuatro subtareas del ticket, con dependencia lineal: el entorno habilita la base reutilizable, esta habilita el endpoint y el endpoint es consumido por el frontend. La creación del bucket real queda fuera de este plan, como tarea separada.

| # | Subtarea | Alcance resumido | ClickUp |
|---|----------|------------------|---------|
| 1 | Entorno local S3 con Floci | Servicio `floci` en `docker-compose.yml`, variables de entorno S3 y bucket de desarrollo al arranque. | [17tjnm2wg59](https://app.clickup.com/t/17tjnm2wg59) |
| 2 | Base S3 en el backend | Dependencias AWS SDK v2 (`s3`, `s3-presigner`), `AwsConfiguration` (beans `S3Client`/`S3Presigner`) y `S3Service` mínimo (subir + URL firmada GET). | [17tjnm2wg5b](https://app.clickup.com/t/17tjnm2wg5b) |
| 3 | Endpoint de foto de socio | `MemberPhotoService` con key `{marca}/members/{id}/photo`, endpoints `POST`/`GET /api/member/{id}/photo`, validación de tipo y tamaño. | [17tjnm2wg5d](https://app.clickup.com/t/17tjnm2wg5d) |
| 4 | Modal y acción en el catálogo | Acción "Imagen de usuario" en la columna "Acciones", modal de carga (Angular Material) y servicio TS que muestra la foto. | [17tjnm2wg5f](https://app.clickup.com/t/17tjnm2wg5f) |

Floci es un emulador de AWS local (equivalente a LocalStack) y sirve únicamente para desarrollo; no sustituye al bucket de producción.

## Fuentes

- [Ticket ClickUp 86akm8wag - Fotos de Socios](https://app.clickup.com/t/86akm8wag)
- Patrón de referencia: integración de S3 y URLs firmadas en UTEM-API (`S3Service`, `AwsConfiguration`, controladores de foto de perfil).
- [Floci - Quick Start (emulador de AWS local)](https://floci.io/floci/getting-started/quick-start/)
