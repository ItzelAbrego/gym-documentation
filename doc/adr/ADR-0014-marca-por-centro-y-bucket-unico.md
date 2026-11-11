# ADR-0014: La marca es atributo del centro; un solo bucket con prefijo por centro

**Estado**: Aceptada · **Fecha**: 2026-11-05
**Origen**: entrevista `sdd-grill-idea`, 7 rondas, slug `migracion-instancia-limpia` · spec pendiente
**Enmienda a**: [ADR-0012](ADR-0012-almacenamiento-fotos-de-socios.md)

## Contexto

ADR-0012 parte de una premisa explícita: "El despliegue es de una sola marca por
instalación. La marca se configura con `gym.brand` (variable de entorno `GYM_BRAND`) y
hoy toma los valores `fitroom` o `fussion`. El backend es dueño de la marca y
`BrandingService.activeBrand()` ya expone el valor normalizado". De ahí salen las llaves
de S3 `{marca}/members/{id}/photo`.

Esa premisa deja de ser cierta con ADR-0013. Si FitRoom y Fussion comparten un solo
backend, **una variable de entorno no puede servir a dos marcas**: el proceso tendría
que ser de una marca y de la otra al mismo tiempo.

## Decisión

1. **La marca pasa a ser columna de `centers`.** El backend sigue siendo su dueño: lo
   que cambia es de dónde la resuelve — del centro del token autenticado (ADR-0004) en
   lugar del ambiente.
2. **Un solo bucket de S3**, con **folder/prefijo por centro**. No habrá más buckets; las
   llaves de AWS son compartidas.
3. **Las fotos ya almacenadas no se re-llavean.** Los objetos que hoy viven bajo
   `fitroom/members/42/photo` se quedan donde están, y el centro registra su prefijo
   histórico. El esquema por centro aplica a lo nuevo.

## Alternativas consideradas

- **Conservar `GYM_BRAND` por instalación, con dos frontends apuntando al mismo
  backend**: el frontend pasaría a ser dueño de la marca, lo que contradice de frente la
  postura explícita de ADR-0012 ("el backend es dueño de la marca"). Además obliga a
  mantener un segundo despliegue de frontend para siempre, que es parte de lo que
  ADR-0013 viene a eliminar.
- **Un bucket por marca o por centro**: más aislamiento, pero las llaves de AWS son
  compartidas y el equipo decidió que exista exactamente un bucket. Multiplicar buckets
  multiplica políticas de IAM y configuración de lifecycle sin ganancia aquí.
- **Copiar los objetos existentes al prefijo nuevo por centro**: dejaría un único
  esquema de llaves, más ordenado para cualquiera que lea el bucket después. Rechazada
  por costo: una pasada sobre todas las fotos de socios de los dos gimnasios, para una
  ganancia cosmética, cuando referenciar el prefijo histórico es gratis hoy.

## Consecuencias

**Positivas**

- Un centro nuevo trae su marca como dato; no requiere despliegue ni variable de entorno.
- Un bucket, una configuración de lifecycle.

**Costos aceptados a sabiendas**

- **ADR-0012 queda enmendada**: su premisa de "una sola marca por instalación" ya no
  aplica, y `BrandingService.activeBrand()` tiene que resolver desde el centro, no desde
  el ambiente.
- **Dos esquemas de llaves coexisten indefinidamente** en el bucket: los prefijos
  históricos (`fitroom/`, `fussion/`) y el prefijo por centro para todo lo nuevo.
  Cualquier herramienta futura que recorra el bucket tiene que conocer los dos.
- **Disparador para reabrir**: si los dos esquemas provocan un incidente real — una foto
  que no se encuentra tras renombrar un centro — la pasada de copia se vuelve justificable.

## Puerta

**Puerta de dos sentidos.** Mover la marca a columna es una migración de esquema más un
cambio en un servicio. Y re-llavear las fotos sigue siendo posible después: es una pasada
de copia, y el prefijo histórico queda registrado, así que diferirlo no pierde
información. Lo único que crece con el tiempo es el número de objetos que habría que
copiar.
