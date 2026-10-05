---
id: ST-007
tipo: story
titulo: Vista superadmin de centros
grupo: Superadmin
estado: pendiente
depende_de:
  - ST-006
  - ST-011
adrs:
  - ADR-0003
---

# ST-007 — Vista superadmin: Centros

**Grupo**: Superadmin · **Depende de**: ST-006, ST-011 · **ADRs**: [ADR-0003](../adr/ADR-0003-roles-y-superadministracion.md)

## Historia de usuario

**Como** superadministrador **quiero** una vista de Centros con tabla CRUD
**para** administrar los clientes del sistema desde el navegador.

## Criterios de aceptación

- [ ] Nueva ruta/route accesible solo con `userRole === 'SUPERADMIN'` (guard
      actualizado en ST-011).
- [ ] Tabla de centros (Angular Material, mismo patrón que las vistas existentes
      de `gym-web`): nombre, UUID (corto/copiado), activo, socios, usuarios,
      fecha de alta.
- [ ] Alta de centro: formulario con datos del centro + datos del `CENTER_ADMIN`
      inicial (username, nombre, password) — llama a `POST /api/v1/centers`.
- [ ] Edición de centro (nombre/perfil) y desactivación con confirmación
      (Material dialog, mismo patrón que desactivar usuario).
- [ ] Acción "Entrar al centro": dispara impersonación (ST-009) y navega a la
      vista de centro con banner de modo superadmin.
- [ ] Sección de auditoría: tabla paginada de `audit_log` con filtros (centro,
      actor, acción).

## Notas técnicas

- Agregar el page al listado `MENUITEMS` de `shared/menu-items/menu-items.ts` y
  mapearlo en `app.routing.ts`; hoy el menú solo contempla roles ADMIN/USER/
  REGISTRATION.
- Reutilizar el componente de tabla paginada existente de la app (p. ej. el de
  la vista `user`) para consistencia visual.
