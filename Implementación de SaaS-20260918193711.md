# Implementación de SaaS

En este documento estará todo lo relacionado sobre los cambios necesarios para hacer funcionar el sistema como SaaS para diversos clientes (centros de Gym).
# Administración y roles del sistema

Funcionalidades relacionadas a la administración del sistema sobre y entre centros. Incluye la definición de límites entre administración de sistema y de centro.

*   Modo superadministrador: vistas para poder administrar la aplicación. Incluye funcionalidades como dar de alta nuevos centros, bajo que planes se rigen, manejo de usuarios, etc.
*   Modo cliente (nombre por definir): vistas de operación del centro.
## Tablas de administración
Esta parte del sistema usará estas tablas:
**Centros**

| Nombre | Tipo | Notas |
| ---| ---| --- |
| id | Unsigned long | ID númerico para fácil acceso e indexado. |
| center\_uuid | UUID (binario) | Cualquier integración externa usará este identificador para no exponer el ID númerico. |
| name | String |  |
| active | Booleano |  |

**Sucursales**

| Nombre | Tipo | Notas |
| ---| ---| --- |
| ID | UUID (binario) |  |
| Nombre | String |  |

*   Datos financieros no pueden estar directamente ligados a sucursales. Si son eliminadas, estos deben permanecer por motivos de auditoría y demás utilidad para los clientes.
    Por ahora las sucursales no serán consideradas y ningún dato será ligado directamente a ellas debido a la posibilidad de eliminado o volatilidad que pudiese afectar funcionamiento. Solo se relacionarán las entidades que sean estricc. _A need to be related basis_.
### Preguntas
*   ¿Se necesita un ID númerico? ¿Por motivos de indexado y fácil relación?
*   ¿Qué tan difícil es tener que las configuraciones apunten a la tabla de Centros y más tarde se cambien a Sucursales?
*   ¿Sería mejor crear una tabla separada por sucursales más adelante y que la existente sean configuraciones heredables?
*   ¿Necesitamos un centro para definir a los superadministradores?
*   ¿A caso debemos relacionar algo directamente a las sucursales?
## Roles
Estos son los roles identificados:
*   Administrador
*   **Staff (cambiar en código)**
*   Registro
Roles nuevos identificados al momento:
*   Superadministrador
    *   Realiza funciones de administración del sistema.
    *   Puede ver todos los centros registrados.
    *   Crea nuevos centros.
    *   Cambia/asigna planes (funcionalidades) a cada centro.
    *   Puede activar o desactivar centros.
    *   En resumen, puede hacer "todo".
    
*   Adminitración de centro (Billing)
    *   Usuario principal de un centro.
    *   Puede realizar todas las operaciones de administración de un centro.
    *   Como crear nuevos usuarios, cambiar roles de usuarios.
    *   No puede ser afectado por otros usuarios.
    *   Este usuario necesita proporcionar su correo electrónico para notificaciones importantes.
    
    No confundir con socios (Member). Solo para quienes operan el centro y administradores del sistema.
    
### Preguntas
*   ¿Qué otros roles son necesarios?
    
    No por el momento. Surgirá sobre la demanda.
    
*   ¿El administrador podría convertirse en usuario de facturación (**Billing**)?
    
    Puede haber más de uno. El cambio se le debe solicitar a un superadministrador.
    
*   ¿Deberíamos llamar de otro modo al usuario de facturación (Billing)?
    
    Cambiar nombre a Administrador de centro (center\_admin).
    
*   ¿Pueden los superadministradores entrar a un centro sin estar afiliado a él?
    
    Si, por motivos de ayuda remota o depuración. Se debe agregar log de auditoría para esto.
    
*   ¿Un superadmin pueden fungir como usuario de facturación?
    
    No, serán usuarios separados de modo que sean auditables las acciones de los tipos de usuarios.
    
## Acceso
Al autenticarse se debe revisar el tipo de rol:
*   Si es superadministrador, se redirige a la interfaz de Superadministrador.
*   Si es cualquier otro usuario, se redirige a la interfaz de administración del centro.
    *   Aplican las restricciones del rol que tenga.
### Tareas
- [ ] Definir comportamiento para acceder a la interfaz de centro desde Superadministrador.
### Preguntas
Ninguna.
## Modo superadministrador
Vistas identificadas al momento:
*   Centros
*   Usuarios
#### Tareas
- [ ] Definir vistas
- [ ] Definir nuevas tablas
#### Preguntas
*   ¿Qué otra información necesitamos visualizar?
### Vista Centros
*   Muestra todos los centros registrados en el sistema.
*   Se pueden crear, editar y borrar centros desde aquí.
*   Desde el catálogo se pueden desactivar los centros.
*   Se debe considerar el borrado por pasos (borrado lógico y borrado "físico" asíncrono).
*   El superadmin puede acceder a cada centro desde la vista de centros. El menú de usuarios (y otro lugar a fin) tendrá una opción extra para regresar a la vista de superadministrador.

Cosas a considerar al crear un nuevo centro:
*   Se debe asignar un usuario como usuario de facturación. Si no existe, desde aquí se debe crear.
*   Se le debe asignar un plan.
### Vista Usuarios
*   La tabla de base de datos de usuarios guarda también usuarios de superadministrador.
*   Esta vista contará con filtros para poder visualizar solo usuarios superadministrador, usarios de facturación y todos los usuarios.
*   Por default, mostrará usuarios superadministrador.
*   Los nuevos usuarios de facturación para un centro pueden ser creados desde aquí.
#### Preguntas
*   ¿Un superadministrador puede editar a otro superadministrador?
    
    No se pueden editar entre ellos.
    
*   ¿Se necesita un rol maestro de superadministrador?
    
    No por el momento.
    
*   ¿Necesitamos ver todos los usuarios desde una misma vista? ¿O solo superadministradores y de facturación?
    
    Todos los usuarios son visibles en esta vista. Por default, no filtrar esta vista. Sin embargo, tendrá diversos filtros como roles, nombres, etc.
    
# Actualización de funcionalidades actuales

Cómo serán afectadas las funcionalidades actuales tanto en el backend como frontend.

Todos los cambios sobre el frontend **no relacionados a la vista de superadministrador** serán para adaptar el funcionamiento actual. No deberán afectar la apariencia o los flujos que usan los usuarios.

Todos los cambios sobre las funcionalidades ya existentes serán únicamente para adaptarse al compartimiento de la información y operación en relación con su centro.

Vistas actuales:

*   Usuarios
*   Socios
*   Planes
*   Turnos
*   Suscripciones
*   Nueva suscripción

*   Check-in
*   Ventas
*   Inventario
*   Reportes
*   Configuración

## Tareas
- [x] Identifica que debe cambiar en las vistas.
- [ ] Identifica que tablas deben relacionarse con la de Centro.
- [ ] Identifica y documenta flujo de relación de entidades para cumplir tarea anterior.
- [ ] Definir cambios sobre autenticación.
- [ ] Definir cambios sobre autorización.
## Autenticación
*   Todos los usuarios iniciarán sesión como lo hacen actualmente.
*   Cada usuario (no superadministrador) está relacionado únicamente a un solo centro.
*   La respuesta del endpoint de autenticación incluirá el UUID de organización.
*   El UUID se guardará por el frontend (local storage o similar) para ser usado en todas las peticiones pertinentes.
*   Como alternativa el UUID se obtiene en el filtro que valida el token y se pasa como propiedad a cada endpoint.
### Preguntas
*   Revisar casos de uso de turnos para evitar problemas con que usuarios hagan modificaciones fuera de instalaciones.
    
    Esto necesitará amplia consideración para evitar cambios con mala intenciones en datos de los centros.
    
    *   Obligar cambiar a estado especial después de 8 horas.
    *   Al cerrar y abrir turno, mandar solicitud de aprobación al administrador.
    
*   ¿Cómo se identifica un usuario para ingresar a un gym?
    
    Usa su correo. Los correos deben ser únicos en todo el sistema.
    

### Tareas
- [x] Checar información retornada por endpoint de autenticación.
## Usuarios
*   Los usuarios solo pueden pertenecer a un centro.
*   Los usuarios en esta vista serán buscados por UUID de centro.
*   Los usuarios en esta vista no pueden tener un rol mayor a superadministrador.
*   Los usuarios superadministrador no pueden pertenecer a un centro.\*
*   Los usuarios requerirán un correo único para su registro.
    Cada centro solo podrá ver los usuarios relacionados a su centro y cuyos roles no son mayores a Facturación.
## Socios
*   Los socios son únicos para un centro, más los números de teléfono no.
*   Un socio puede usar su mismo número de teléfono en diferentes centros:
    *   Internamente se buscará por número de teléfono y UUID de centro.
    *   Un socio en Gym A tiene que ser registrado con su teléfono.
# Migración de datos
## Preguntas
*   ¿Cómo se deben ingresar los datos para ser migrados?
    
    Se generará un backup de la base original y con un script de Python o similar se alterará para incluir los datos que falta en cada tabla identificada.
    
*   ¿Qué pasos preliminares deben considerarse?
*   ¿Cómo se relacionarán los datos a un centro?
*   ¿Cómo se crea un nuevo centro al iniciar la migración?
*   ¿Si se interrumpe una migración como se reanuda?
*   ¿Cómo se asegura la integridad de los datos?
*   ¿Hay alguna forma de probar automatizadamente?
    
    No invertiremos tiempo en esto.
    
# Tickets

Esta lista está sujeta a cambio. Hasta que los tickets no sean escritos, pueden ser divididos o removidos.

### Principal
Cambios de lo que de dependerá todo lo demás.
*   Crear tabla de centros.
*   Crear tabla para relacionar usuarios con centros
*   Actualizar proceso de inicialización para considerar
### Superadministrador
*   Crear entidad, repository y método para obtener todos los centros
*   Crear endpoint para obtener todos los repositorios
*   Crear método de servicio para crear nuevo centro
    *   Consideración: debe tener un usuario a ligar
*   Crear endpoint para crear nuevo centro
    *   Consideración: petición debe tener información de nuevo usuario