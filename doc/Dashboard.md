# Dashboard de documentación

> Esta página se actualiza automáticamente cuando el plugin **Dataview** está habilitado.

## Stories

```dataview
TABLE WITHOUT ID
  id AS "ID",
  link(file.path, titulo) AS "Story",
  estado AS "Estado",
  grupo AS "Grupo",
  choice(length(depende_de) = 0, "—", join(depende_de, ", ")) AS "Depende de",
  join(adrs, ", ") AS "ADRs"
FROM "doc/stories"
SORT id ASC
```

### Stories sin dependencias

```dataview
TABLE WITHOUT ID
  id AS "ID",
  link(file.path, titulo) AS "Story"
FROM "doc/stories"
WHERE length(depende_de) = 0
SORT id ASC
```

### Stories pendientes

```dataview
TABLE WITHOUT ID
  id AS "ID",
  link(file.path, titulo) AS "Story",
  grupo AS "Grupo",
  choice(length(depende_de) = 0, "—", join(depende_de, ", ")) AS "Depende de"
FROM "doc/stories"
WHERE estado = "pendiente"
SORT id ASC
```

## ADRs

```dataview
TABLE WITHOUT ID
  file.link AS "ADR",
  file.mtime AS "Última modificación"
FROM "doc/adr"
SORT file.name ASC
```

## Otros documentos

```dataview
TABLE WITHOUT ID
  file.link AS "Documento",
  file.mtime AS "Última modificación"
FROM "doc"
WHERE !contains(file.path, "/stories/")
  AND !contains(file.path, "/adr/")
  AND file.name != this.file.name
SORT file.name ASC
```

## Cómo usarlo

Para añadir estados, grupos o dependencias a las stories, agrega metadatos YAML al inicio de cada nota:

```yaml
---
estado: pendiente
grupo: Principal
depende_de:
  - ST-001
---
```

Luego esos campos pueden incorporarse a la tabla, por ejemplo:

```dataview
TABLE estado, grupo, depende_de
FROM "doc/stories"
SORT file.name ASC
```
