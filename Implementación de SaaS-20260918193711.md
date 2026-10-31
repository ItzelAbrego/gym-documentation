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

**Sucursales (branches)**

> **Actualización (ADR-0010, 2026-09-21):** las sucursales **dejaron de estar pospuestas**.
> El ADR-0008 original las difería, pero al preparar la propuesta al cliente se decidió
> **diseñarlas e implementarlas desde el inicio**, por el requisito de **contabilidad exacta
> y separada por sucursal**. El modelo completo vive en
> [ADR-0010](doc/adr/ADR-0010-sucursales-contabilidad-aislada.md) y en las stories
> [ST-015](doc/stories/ST-015-tabla-branches-y-admin.md) y
> [ST-016](doc/stories/ST-016-scoping-por-sucursal.md). El DDL objetivo está en
> `doc/schema-propuesta.sql`.

| Nombre | Tipo | Notas |
| ---| ---| --- |
| id | BIGINT | PK/FK interna (auto-increment), mismo tipo que `centers.id`. |
| branch_uuid | BINARY(16) | Identificador externo (API); nunca se expone `id`. |
| center_id | BIGINT | FK a `centers`. 1 centro : N sucursales. |
| name | String |  |
| active | Booleano | Solo desactivación lógica; **nunca** borrado físico (protege contabilidad histórica). |

Jerarquía: **Superadmin → Centro → Sucursal → datos operativos**. El **centro sigue siendo
el límite del tenant** (claim `center_uuid`); la sucursal es una **sub-división interna** del
centro, nunca un tenant nuevo.

**Qué se liga a sucursal vs a centro (ADR-0010):**

*   **A nivel sucursal (`branch_id` NOT NULL)** — dinero y operación física: `work_shifts`,
    `work_shifts_notes`, `debit_transactions`, `cancellations`, `sale`, `sales_details`,
    `purchase`, `inventory`, `check_in`, `check_out`, `invalid_check_ins`, y la nueva tabla
    `branch_stock`. Cada peso cobrado y cada movimiento de stock queda marcado con su sucursal.
*   **A nivel centro (`center_id`, sin `branch_id`)** — el socio y sus beneficios siguen siendo
    del centro: `members`, `subscriptions`, `member_membership`, `courtesies`, `member_status`,
    `member_fingerprint_templates`. También los catálogos: `rates`, `membership_config`,
    `rate_allowed_methods`, catálogo de `articles`, y `gym_config`.
*   **Caso mixto:** `gym_profile` **baja a nivel sucursal** (cada ubicación tiene su nombre,
    teléfono, dirección y redes); `gym_config` se queda a nivel centro.

**Invariante contable (anti-mezcla):** toda tabla con `center_id` + `branch_id` referencia la
sucursal con FK compuesta `FOREIGN KEY (branch_id, center_id) REFERENCES branches(id, center_id)`
(requiere `UNIQUE KEY (id, center_id)` en `branches`). Así una fila nunca puede quedar ligada a
la sucursal de otro centro.

### Decisiones
*   ¿Se necesita un ID númerico? ¿Por motivos de indexado y fácil relación?
    
    Sí. `id` **BIGINT** auto-increment como PK y FK interna (joins e indexado baratos) + `center_uuid` BINARY(16) solo para integraciones externas. Mismo criterio para `branches` (`id` BIGINT + `branch_uuid`).
*   ¿Qué tan difícil es tener que las configuraciones apunten a la tabla de Centros y más tarde se cambien a Sucursales?
    
    Resuelto por diseño: ya no se difiere. `gym_config` queda a nivel centro y `gym_profile` a nivel sucursal desde el inicio (ADR-0010 regla 10). La cascada de configuraciones centro → sucursal y los precios por sucursal sí quedan como fase posterior.
*   ¿Sería mejor crear una tabla separada por sucursales más adelante y que la existente sean configuraciones heredables?
    
    Las sucursales se crean **ya** (tabla `branches`). La heredabilidad/override de configuraciones por sucursal se difiere a fase posterior.
*   ¿Necesitamos un centro para definir a los superadministradores?
    
    No. `users.center_id` es nullable; `NULL` = superadministrador. Sin centro "fantasma". `users.branch_id` también es nullable: obligatorio para `STAFF`/`REGISTRATION`/quiosco, opcional para `ADMIN` (decisión P-13), NULL para `CENTER_ADMIN`/`SUPERADMIN`.
*   ¿A caso debemos relacionar algo directamente a las sucursales?
    
    Sí: dinero y operación física (ver lista arriba). Los datos financieros se ligan a sucursal **y permanecen** aunque la sucursal se desactive, porque las sucursales solo se desactivan lógicamente, nunca se borran — con eso se satisface a la vez la contabilidad por sucursal y la regla de permanencia histórica del doc base.
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
### Comportamiento definido
- [x] Comportamiento para acceder a la interfaz de centro desde Superadministrador:
    *   El superadmin entra al centro mediante **impersonación**: toma un rol `center_admin` temporal para esa sesión.
    *   Se muestra un **banner visible** indicando que se opera en modo superadmin, con opción de regresar a la vista de superadministrador.
    *   Toda acción realizada durante la impersonación se registra en el **log de auditoría** (quién, cuándo, en qué centro, qué acción).
    *   Al terminar, la sesión regresa al contexto de superadministrador sin afectar usuarios reales del centro.
## Modo superadministrador
Vistas identificadas al momento:
*   Centros
*   Usuarios
#### Tareas
- [x] Definir vistas (ver abajo)
- [x] Definir nuevas tablas (ver abajo)
#### Preguntas
*   ¿Qué otra información necesitamos visualizar?
    
    Pendiente de definir al construir las vistas. Candidatos: conteo de usuarios/socios activos por centro, estado del plan contratado.
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
#### Tablas nuevas definidas
*   **centers**: `id` INT auto-increment (PK/FK interna), `center_uuid` BINARY(16) (integraciones externas), `name`, `active`.
*   **users.center_id** (columna nueva, nullable): `NULL` = superadministrador. El rol `center_admin` se expresa vía `user_role` + `center_id` del centro correspondiente.
*   **audit_log**: registro de auditoría para impersonación y acciones de superadmin (superadmin, centro, acción, timestamp).
*   **plans / center_plans** (fase posterior de planes): catálogo de planes y su asignación por centro.
#### Nota sobre gym_profile
`gym_profile` pasa a vivir **a nivel sucursal** (`branch_id`), no a nivel centro: cada ubicación física tiene su propio nombre, teléfono, dirección y redes (ADR-0010 regla 10). No se fusiona con `branches` (se mantiene como tabla propia ligada por `branch_id`). `gym_config` sí permanece a nivel centro.
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
- [x] Identifica que tablas deben relacionarse con la de Centro.
- [x] Identifica y documenta flujo de relación de entidades para cumplir tarea anterior.
- [x] Definir cambios sobre autenticación.
- [x] Definir cambios sobre autorización.

## Tablas que se relacionan con Centro y con Sucursal
Scoping en dos niveles (ADR-0010). El **centro** (`center_id`) es el límite del tenant; la
**sucursal** (`branch_id`) marca dónde ocurre el dinero y la operación física.

**Llevan `center_id` (FK a `centers`):**

| Grupo | Tablas |
| --- | --- |
| Acceso y roles | `users` (nullable, ver superadmins; además `branch_id` nullable), `gym_config`, `gym_config_history` |
| Socios | `members`, `member_fingerprint_templates`, `member_status` |
| Catálogos y tarifas | `membership_config`, `rates`, `rates_table_history`, `rate_allowed_methods`, `articles` (catálogo) |
| Suscripciones | `member_membership`, `subscriptions`, `subscription_history`, `courtesies`, `courtesy_history` |
| Turnos y dinero | `work_shifts`, `work_shifts_notes`, `debit_transactions`, `cancellations` |
| Check-in | `check_in`, `check_out`, `invalid_check_ins` |
| Ventas e inventario | `inventory`, `sale`, `sales_details`, `purchase` |

**Llevan además `branch_id` NOT NULL (dinero/operación física — FK compuesta a `branches(id, center_id)`):**

| Grupo | Tablas |
| --- | --- |
| Turnos y dinero | `work_shifts`, `work_shifts_notes`, `debit_transactions`, `cancellations` |
| Check-in | `check_in`, `check_out`, `invalid_check_ins` |
| Ventas e inventario | `sale`, `sales_details`, `purchase`, `inventory`, y la nueva `branch_stock` |

**Cambio de nivel:** `gym_profile` pasa de `center_id` a `branch_id` (perfil por ubicación física).

**Solo `branch_id` indirecto (heredan de su padre, sin columna propia):** `sales_articles`,
`purchase_details`, `checkin_subscription`, `checkin_courtesy`.

No se tocan (catálogos globales compartidos entre centros): `states`, `cities`, `colonias`.

> Nota: `articles.stock` **se elimina del dominio**; el stock pasa a `branch_stock`
> (`branch_id`, `article_id`, `quantity`) como única fuente de verdad por sucursal (ADR-0010, N-08).

## Flujo de relación de entidades
1. **Centro** es la raíz del tenant: todo registro operativo recibe `center_id` directamente de `centers`.
2. **Sucursal** es sub-división del centro: las tablas de dinero y operación física reciben además `branch_id` (FK compuesta con `center_id` para impedir mezclas entre centros).
3. Desde el centro se derivan: `users` (staff, con `branch_id` opcional/obligatorio según rol), `members` (socios del centro), configuraciones (`gym_config` por centro, `gym_profile` por sucursal) y catálogos (`rates`, `membership_config`, `articles`).
4. Las transacciones se encadenan dentro de la sucursal: `work_shifts` (branch) → `debit_transactions` (branch) → `member_membership` / `subscriptions` (centro) / `sale` (branch) / `cancellations` (branch) → `check_in` / `check_out` (branch) / `courtesies` (centro). El beneficio es del centro; el dinero que lo originó vive en la sucursal donde se cobró.
5. Las tablas de detalle e historial (`*_history`, `*_details`, `*_notes`, tablas de unión check-in) heredan `center_id`/`branch_id` de su tabla padre o lo llevan propio, según coste de consulta.
## Autenticación
*   Todos los usuarios iniciarán sesión como lo hacen actualmente.
*   Cada usuario (no superadministrador) está relacionado únicamente a un solo centro.
*   La respuesta del endpoint de autenticación incluye el UUID de organización para referencia del frontend.
*   Decisión: el UUID viaja como **claim del JWT**; el filtro que valida el token lo extrae y lo pasa como propiedad a cada endpoint. El frontend no envía el UUID en peticiones — una sola fuente de verdad, no manipulable desde el cliente.
*   El staff asignado a una sucursal lleva además el claim `branch_uuid` (ADR-0010); el filtro lo expone como contexto de operación. `CENTER_ADMIN`/`SUPERADMIN` y `ADMIN` sin sucursal no lo llevan.
*   Los superadministradores reciben el token sin claim de centro.
### Decisiones
*   Revisar casos de uso de turnos para evitar problemas con que usuarios hagan modificaciones fuera de instalaciones.
    
    Decisión: al cerrar o abrir un turno con desfase significativo (fuera del horario del centro o desde conexión remota), se genera una **solicitud de aprobación que el `center_admin` aprueba o rechaza**. No se impone regla dura de 8 horas; la aprobación explícita cubre ambos casos.
    
*   ¿Cómo se identifica un usuario para ingresar a un gym?
    
    Usa su correo. Los correos deben ser únicos en todo el sistema (se mantiene el UNIQUE global sobre `users.username`).
    

### Tareas
- [x] Checar información retornada por endpoint de autenticación.
- [x] Definir cambios sobre autenticación (claim de centro en JWT).
- [x] Definir cambios sobre autorización: roles `SUPERADMIN`, `CENTER_ADMIN` (ex Billing), `ADMIN`, `STAFF`, `REGISTRATION`; cada endpoint valida el claim de centro y el rol, de modo que solo se opere información del propio centro. Impersonación de superadmin evalúa permisos como `center_admin` temporal con auditoría.
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
*   Impacto en el esquema actual (`schema.sql`): `members.cell_phone` tiene UNIQUE global → cambiar a UNIQUE `(center_id, cell_phone)`. `members.email` tiene UNIQUE global → cambiar a único por centro `(center_id, email)` con la misma lógica que el teléfono.
# Migración de datos
## Preguntas
*   ¿Cómo se deben ingresar los datos para ser migrados?
    
    Se generará un backup de la base original y con un script de Python o similar se alterará para incluir los datos que falta en cada tabla identificada.
    
*   ¿Qué pasos preliminares deben considerarse?
    
    Backup completo de la base original; inventario de tablas a alterar (ver lista en "Tablas que se relacionan con Centro y con Sucursal"); aplicar los cambios de unique keys de `members` (teléfono y correo por centro); aplicar el esquema nuevo (Flyway, incluyendo `branches` y `branch_stock`) antes de correr el script.
    
*   ¿Cómo se relacionarán los datos a un centro?
    
    El script asigna el `center_id` del centro creado a todas las filas de las tablas listadas, en el orden del flujo de entidades. Para las tablas de dinero/operación, además asigna el `branch_id` de la **sucursal principal** creada para ese centro.
    
*   ¿Cómo se crea un nuevo centro al iniciar la migración?
    
    El script crea el centro tomando el nombre de `gym_profile` de la base original, crea su **sucursal principal** (a la que apunta todo `branch_id` histórico) y liga `gym_config` al centro y `gym_profile` a la sucursal principal. Traslada los saldos de `articles.stock` a `branch_stock` de la sucursal principal.
    
*   ¿Si se interrumpe una migración como se reanuda?
    
    No hay reanudación: el script es one-shot. Si falla, se restaura el backup y se reintenta desde el inicio.
    
*   ¿Cómo se asegura la integridad de los datos?
    
    El script imprime conteos por tabla antes y después de la migración para verificación manual. Sin verificación automática ni pruebas automatizadas.
    
*   ¿Hay alguna forma de probar automatizadamente?
    
    No invertiremos tiempo en esto.
    
# Tickets

Esta lista está sujeta a cambio. Hasta que los tickets no sean escritos, pueden ser divididos o removidos.

### Principal
Cambios de lo que de dependerá todo lo demás.
*   Crear tabla `centers` (id BIGINT + center_uuid).
*   Crear tabla `branches` (id BIGINT + branch_uuid, `center_id` NOT NULL, 1 centro : N sucursales; solo desactivación lógica) — ST-015.
*   Agregar `users.center_id` nullable (NULL = superadmin) y `users.branch_id` nullable (por rol); migrar rol Billing → `CENTER_ADMIN`.
*   Crear tabla `audit_log`.
*   Cambiar unique keys de `members`: `(center_id, cell_phone)` y `(center_id, email)`.
*   Agregar `center_id` a todas las tablas del mapeo, y `branch_id` NOT NULL (FK compuesta a `branches(id, center_id)`) a las tablas de dinero/operación — ver "Tablas que se relacionan con Centro y con Sucursal" (ST-004, ST-016).
*   Crear tabla `branch_stock` y retirar `articles.stock` del dominio — ST-016.
*   Actualizar proceso de inicialización (Flyway/seed) para considerar el centro, su sucursal principal y sus datos base.
### Superadministrador
*   Crear entidad, repository y método para obtener todos los centros
*   Crear endpoint para obtener todos los centros
*   Crear método de servicio para crear nuevo centro
    *   Consideración: debe tener un usuario a ligar
    *   Consideración: crea también la sucursal principal y su usuario quiosco
*   Crear endpoint para crear nuevo centro
    *   Consideración: petición debe tener información de nuevo usuario
*   Vistas superadmin: Centros (CRUD, activar/desactivar, entrar al centro) y Usuarios (todos con filtros)
*   Impersonación de centro con rol temporal, banner y auditoría
*   Activar/desactivar centros (borrado lógico + físico asíncrono)
*   Administración de sucursales del centro (CRUD + desactivación lógica) — ST-015
### Adaptación de funcionalidades
*   Emitir claim `center_uuid` (y `branch_uuid` para staff con sucursal) en el JWT; extraerlo en el filtro y pasarlo a los endpoints
*   Scopes/validación por centro en cada endpoint existente; scoping por sucursal en dinero/operación (ST-016)
*   Flujo de aprobación de turnos (apertura/cierre con desfase) hacia `center_admin`, evaluando el horario de la sucursal del turno
### Migración
*   Script Python one-shot sobre backup: crear centro + sucursal principal, asignar `center_id`/`branch_id`, trasladar stock a `branch_stock`, ajustar unique keys, conteos finales antes/después