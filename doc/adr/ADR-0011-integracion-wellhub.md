---
id: ADR-0011
tipo: adr
titulo: Integración de FitRoom con Wellhub
estado: propuesta
fecha: 2026-10-12
---

# ADR-0011: Integración de FitRoom con Wellhub

**Estado**: Propuesta · **Fecha**: 2026-10-12

## Contexto

Wellhub es una plataforma de bienestar que las empresas ofrecen a sus colaboradores. Cuando un gimnasio se incorpora como partner, los usuarios cuyo plan incluya ese establecimiento pueden visitarlo y el gimnasio recibe el pago correspondiente a los check-ins validados.

La incorporación del gimnasio y la integración del sistema son procesos relacionados, pero distintos. Primero se debe formalizar la relación comercial y activar la sede en el Portal de Partners. Después se solicita a Wellhub la evaluación técnica del sistema de gestión.

FitRoom necesita definir tanto el procedimiento administrativo para operar como partner como el mecanismo técnico que registrará y validará las visitas. La activación depende del contrato, las credenciales y la autorización final de Wellhub.

## Decisión propuesta

Integrar FitRoom mediante Access Control API v1 y el webhook de check-in de Wellhub una vez aprobada la relación comercial. FitRoom relacionará cada usuario con su Wellhub ID, distinguirá las sedes con el `gym_id` asignado, validará automáticamente las visitas y conservará el Portal de Partners como contingencia.

La solución implementará el disparador automático exigido por Wellhub y un segundo mecanismo de validación asociado al acceso físico o al registro de asistencia. Las visitas de Wellhub se mantendrán separadas de las membresías y cobros vendidos directamente por el gimnasio.

Esta decisión permanece en estado **Propuesta** hasta que Wellhub evalúe el sistema, confirme los casos de prueba y autorice la activación en producción.

## Alta del gimnasio como partner

Wellhub publica como requisito previo tener un Perfil de Empresa de Google activo. Este perfil se utiliza para comprobar y ubicar correctamente el establecimiento dentro de la aplicación.

La solicitud se inicia desde el formulario oficial de [registro de partners](https://signup.partners.wellhub.com/start/gym). Durante el proceso se proporciona la información del negocio y, una vez habilitado el acceso, se completa el perfil de la sede con:

- nombre y datos de contacto;
- dirección y horarios;
- actividades y servicios disponibles;
- amenidades y condiciones de acceso;
- logotipo y fotografías reales del establecimiento.

Los cambios realizados desde la sección `App Content` del Portal son revisados por el equipo de calidad de Wellhub antes de publicarse. Los horarios, cierres temporales, actividades y reglas de acceso deben mantenerse actualizados.

Wellhub indica que la incorporación como partner no tiene cuota de inscripción ni de cancelación. La aceptación de cada establecimiento y sus condiciones comerciales quedan sujetas a la revisión y al contrato ofrecido por Wellhub.

Fuente: [Wellhub para partners en México](https://wellhub.com/es-mx/partners/) y [administración del perfil](https://wellhub.com/en-us/partner-academy/partner-portal/).

## Contrato y condiciones comerciales

Antes de activar la operación se deben revisar las condiciones disponibles en el contrato y en la sección `Partnership` del Portal de Partners. Ahí se muestran el pago por check-in y las demás reglas aplicables al establecimiento.

Wellhub no publica una tarifa general para todos los gimnasios de México. La documentación oficial señala que las condiciones pueden variar según el tipo de partner, la ubicación y los servicios ofrecidos. El contrato particular debe indicar:

- importe aplicable por check-in;
- cantidad máxima de check-ins pagables por usuario al mes;
- descuentos por volumen, cuando correspondan;
- condiciones aplicables a ausencias y cancelaciones tardías;
- productos, actividades y sedes incluidas;
- cualquier otra condición comercial de la asociación.

Estos datos no deben suponerse ni copiarse de contratos de otros países. La versión firmada y las condiciones mostradas en el Portal son las referencias del gimnasio.

Fuente: [cómo funcionan los pagos](https://wellhub.com/en-us/partner-academy/understand-wellhub-payments/) y [condiciones en el Portal](https://wellhub.com/en-us/partner-academy/partner-portal/).

## Pagos

Para gimnasios, estudios y servicios de bienestar, Wellhub paga por los check-ins validados. El importe se basa en los precios habituales de venta al público del establecimiento y en las condiciones particulares de su contrato.

Un check-in inicia el proceso de pago cuando se completa la validación:

1. El usuario realiza el check-in desde su propia aplicación de Wellhub.
2. El gimnasio confirma que el usuario se encuentra en el establecimiento, ya sea desde el Portal de Partners o mediante un sistema integrado.
3. Wellhub valida las reglas del plan del usuario.

Para el acceso normal al gimnasio, la solicitud debe validarse dentro de los 20 minutos siguientes. Si no se valida correctamente, la visita puede no ser elegible para pago.

Wellhub procesa los pagos mensualmente, alrededor del día 15, por los check-ins del mes calendario anterior. El depósito se envía a la cuenta bancaria registrada y puede aparecer con el nombre `GYMPASS` en el estado de cuenta.

La sección `Finance` del Portal permite consultar:

- ingresos del mes en curso;
- historial de pagos;
- cuenta bancaria registrada;
- condiciones aplicadas a los check-ins.

Si un depósito falla por datos bancarios incorrectos o desactualizados, Wellhub informa que realiza nuevos intentos durante la primera y tercera semana del mes siguiente. La cuenta bancaria debe mantenerse actualizada desde `Finance`.

La sección `Reports` contiene el historial de check-ins y visitantes y permite descargar reportes en formato `.xlsx`. Estos reportes deben compararse periódicamente con los registros del sistema del gimnasio y con el depósito recibido.

Fuente: [pagos para partners](https://wellhub.com/en-us/partner-academy/understand-wellhub-payments/), [proceso de check-in](https://wellhub.com/es-es/partner-academy/proceso-check-in/) y [Portal de Partners](https://wellhub.com/en-us/partner-academy/partner-portal/).

## Facturación en México

La documentación pública de Wellhub consultada no especifica el procedimiento fiscal mexicano para emitir CFDI, tratar el IVA, aplicar retenciones o entregar complementos de pago. Esa información debe solicitarse a Wellhub durante el alta y revisarse con el contador del gimnasio.

Antes de iniciar operaciones deben quedar confirmados por escrito:

- razón social y RFC del receptor del CFDI;
- concepto y uso de CFDI solicitado;
- tratamiento de IVA y retenciones;
- momento en que debe emitirse la factura;
- canal para entregar XML y PDF;
- procedimiento de corrección o cancelación;
- relación entre la factura, el reporte mensual y el depósito.

No deben utilizarse como referencia las instrucciones fiscales publicadas por Wellhub para Estados Unidos, España o Brasil, porque pueden responder a legislaciones y contratos distintos.

## Operación diaria

El personal de recepción debe pedir al usuario que realice su propio check-in desde la aplicación y con su dispositivo personal. Después debe confirmar que la unidad y la actividad seleccionadas sean correctas y validar la presencia dentro del plazo establecido.

En una operación sin integración, la validación se realiza desde `Check-ins to confirm` en el Portal de Partners. Si existe una integración activa, el sistema del gimnasio puede validar automáticamente el check-in cuando el usuario utiliza la huella, un PIN, una tarjeta o el control de acceso configurado.

Durante la primera visita, el usuario debe registrarse en el sistema del gimnasio y asociarse con su Wellhub ID. En las visitas posteriores, el usuario hace check-in en la aplicación y utiliza el medio de acceso registrado.

La mayoría de los planes de acceso estándar permiten un check-in por día. Wellhub también establece un límite de dos dispositivos para realizar check-in. El usuario puede cancelar una solicitud antes de que se valide manualmente, pero no después de su confirmación.

El Portal debe conservarse como alternativa cuando la integración o el control de acceso presenten una falla.

Fuente: [proceso oficial de check-in](https://wellhub.com/es-es/partner-academy/proceso-check-in/) y [configuración de una integración CMS](https://wellhub.com/en-us/partner-academy/cms-integration/).

## Reglas para el personal

Wellhub exige que los usuarios de su plataforma reciban la misma atención profesional que los clientes directos del gimnasio. También establece que los cargos adicionales solo pueden corresponder a servicios premium y opcionales que no formen parte del beneficio estándar.

No está permitido:

- cobrar inscripciones ocultas, entradas obligatorias o penalizaciones no autorizadas;
- exigir un número mínimo de visitas;
- realizar el check-in en nombre del usuario;
- utilizar un dispositivo compartido de recepción para generar check-ins;
- ofrecer regalos o dinero a cambio de check-ins;
- permitir que propietarios, administradores, entrenadores o empleados hagan check-in en su propio establecimiento;
- solicitar un check-in en un producto distinto del servicio utilizado;
- negar el acceso a una persona cuyo plan sea válido para la sede y actividad.

Wellhub puede responder a los incumplimientos con orientación formal, monitoreo, suspensión de la cuenta o terminación del contrato. Durante una suspensión, la sede no puede recibir usuarios y los check-ins no se procesan para pago.

Fuente: [Estándares de conducta del Partner](https://wellhub.com/es-es/partner-academy/estandares-conducta/).

## Solicitud de integración del sistema

Una vez que el gimnasio tenga acceso al Portal de Partners, la evaluación del sistema se solicita de esta forma:

1. Ingresar al Portal de Partners.
2. Abrir la sección `Integrations`.
3. Seleccionar la sede correspondiente.
4. Seleccionar el sistema de gestión utilizado.
5. Si el sistema no aparece en la lista, solicitar de todas formas una evaluación.
6. Presionar `Request Integration`.
7. Consultar el estado de la solicitud desde la misma sección.

El equipo de ingeniería de Wellhub revisa las capacidades del sistema y comunica los siguientes pasos cuando la conexión es viable. Wellhub aclara que cada solicitud se evalúa individualmente y que la aparición de un CMS en su catálogo no garantiza una activación automática.

La integración con Wellhub no tiene costo por parte de Wellhub. La documentación oficial no establece un plazo garantizado de aprobación o implementación.

Fuente: [solicitud y evaluación de una integración CMS](https://wellhub.com/en-us/partner-academy/cms-integration/).

## Información que entrega Wellhub para la integración

El sistema utiliza la Access Control API. Wellhub proporciona las credenciales y datos necesarios durante el proceso técnico:

- token de autenticación Bearer;
- identificador `gym_id` de cada sede;
- secreto para verificar la firma del webhook;
- instrucciones y ambiente de prueba aplicables a la integración.

Estas credenciales no se generan desde la documentación pública y no deben almacenarse en el repositorio ni incluirse en documentos compartidos.

El contacto técnico oficial también debe confirmar los casos de prueba requeridos y autorizar la activación en producción.

Fuente: [Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/getting-started) y [Check-in Webhook](https://developers.wellhub.com/product/access-control-api/1.0/check-in-webhook).

## Endpoints y flujo técnico

La integración utiliza dos comunicaciones distintas. El sistema del gimnasio llama a Wellhub para validar el acceso y Wellhub llama al sistema del gimnasio para notificar que el usuario hizo check-in.

### Validación de acceso: sistema del gimnasio hacia Wellhub

El endpoint productivo documentado por Wellhub es:

```http
POST https://api.partners.gympass.com/access/v1/validate
Content-Type: application/json
Authorization: Bearer {WELLHUB_AUTH_TOKEN}
X-Gym-Id: {GYM_ID}

{
  "gympass_id": "0123456789012",
  "custom_code": "CODIGO_LOCAL"
}
```

`gympass_id` es obligatorio y debe contener el identificador de 13 dígitos del usuario. `custom_code` es opcional, no puede estar vacío y admite un máximo de 13 caracteres. `X-Gym-Id` identifica la sede en la que se intenta validar el acceso; por lo tanto, cada sucursal debe utilizar el identificador asignado por Wellhub.

La respuesta satisfactoria identifica al usuario, la sede, el producto utilizado y la fecha de validación. Si el acceso no puede validarse, el sistema debe interpretar y mostrar al personal alguno de estos resultados documentados por Wellhub:

- check-in no encontrado: el usuario debe volver a realizarlo en la aplicación;
- check-in ya validado: ya existe una validación para ese usuario ese día;
- check-in expirado: el usuario debe hacer un check-in nuevo;
- check-in cancelado: el usuario canceló la solicitud;
- credenciales inválidas: la API responde con HTTP `401`.

Si la llamada termina por timeout, Wellhub permite repetirla con el mismo contenido y señala que no registrará más de una validación para el mismo acceso.

### Webhook de check-in: Wellhub hacia el sistema del gimnasio

El gimnasio debe proporcionar a Wellhub una URL pública HTTPS que reciba una petición `POST` con `Content-Type: application/json`. La ruta concreta la define el sistema del gimnasio; por ejemplo:

```http
POST https://api.gimnasio.com/integrations/wellhub/check-ins
Content-Type: application/json
X-Gympass-Signature: {FIRMA}
```

El cuerpo enviado por Wellhub incluye:

- `event_type`, con el valor `checkin`;
- `event_data.user.unique_token`, que corresponde al Wellhub ID;
- datos del usuario que Wellhub haya habilitado para la integración;
- coordenadas de la sede;
- identificador y nombre del gimnasio;
- identificador y descripción del producto;
- fecha y hora del evento en `timestamp`.

El receptor debe verificar `X-Gympass-Signature` antes de procesar el evento. Según la documentación oficial, Wellhub calcula la firma aplicando `HMAC-SHA-1` al cuerpo HTTP original con el secreto entregado por Tech Sales y expresa el resultado en mayúsculas. El cuerpo debe conservarse sin modificaciones hasta terminar esta comprobación.

Wellhub espera una respuesta del webhook en un segundo. Si no la recibe, realiza tres reintentos inmediatos. Por este motivo, el endpoint debe responder rápidamente y procesar de forma idempotente una misma notificación más de una vez.

Después de aceptar un webhook legítimo, el flujo automático debe llamar a `POST /access/v1/validate`. Recibir el webhook no equivale por sí solo a validar la visita ni a generar el pago.

Fuente: [endpoints oficiales de Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/endpoints), [Check-in Webhook](https://developers.wellhub.com/product/access-control-api/1.0/check-in-webhook) y [preguntas frecuentes de Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/faq).

### Endpoints opcionales para el código de acceso

Si el gimnasio quiere asociar un PIN, QR u otro código interno al usuario de Wellhub, la API también documenta estas operaciones:

| Operación | Endpoint | Resultado esperado |
| --- | --- | --- |
| Crear | `POST https://api.partners.gympass.com/access/v1/code/{wellhub_id}` | `201 Created` |
| Actualizar | `PUT https://api.partners.gympass.com/access/v1/code/{wellhub_id}` | `200 OK` |
| Eliminar | `DELETE https://api.partners.gympass.com/access/v1/code/{wellhub_id}` | `204 No Content` |

Las tres operaciones requieren `Authorization: Bearer` y `X-Gym-Id`. En creación y actualización, el cuerpo contiene `custom_code`; en eliminación no se envía ese cuerpo. Estos endpoints solo son necesarios si se decide sincronizar el medio de acceso local con Wellhub.

## Validaciones para que Wellhub autorice la integración

Wellhub no publica una lista cerrada de certificación. Los casos definitivos y la autorización para producción los confirma Tech Sales durante el proceso. Sin embargo, su documentación sí establece que la solución debe demostrar lo siguiente:

1. El sistema puede integrarse con una API REST y utilizar las credenciales entregadas por Wellhub.
2. Cada usuario se registra en el sistema del gimnasio y queda relacionado con su Wellhub ID.
3. El usuario siempre realiza el check-in en la aplicación de Wellhub antes de intentar entrar.
4. La validación se envía con el Wellhub ID y el `X-Gym-Id` de la sede correcta.
5. Se implementan dos mecanismos de validación. Uno debe ser obligatoriamente el disparador automático basado en el webhook; el otro puede ser el acceso físico —torniquete, tarjeta, PIN o biometría— o el registro de asistencia en el sistema.
6. El webhook acepta JSON, comprueba la firma y responde dentro del límite de un segundo.
7. El flujo automático consume el evento de check-in y llama a la Access Control API para confirmar la visita.
8. Los errores de check-in no encontrado, validado, expirado o cancelado se manejan sin conceder un acceso incorrecto y se muestran al personal.
9. Los reintentos y timeouts no crean registros duplicados ni permiten más de un acceso por la misma validación.
10. Las sedes se distinguen mediante su propio `gym_id` aunque una red utilice un solo token de autenticación.
11. El gimnasio conserva el Portal de Partners como contingencia para validar manualmente durante una falla temporal.
12. Los casos acordados se prueban con el mecanismo de pruebas de Wellhub y la activación no ocurre hasta recibir la autorización del equipo de Wellhub.

No debe prometerse una aprobación automática. La documentación indica que, al terminar satisfactoriamente el proceso, el equipo de relación de Wellhub autoriza que las nuevas sedes integradas aparezcan en su sistema.

Fuente: [guía inicial de Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/getting-started) y [preguntas frecuentes oficiales](https://developers.wellhub.com/product/access-control-api/1.0/faq).

## Cambios necesarios en el sistema del gimnasio

Para operar con Wellhub, el sistema debe:

- guardar el Wellhub ID y relacionarlo con el socio local;
- identificar la sede de Wellhub a la que pertenece cada validación;
- recibir de forma segura las notificaciones de check-in;
- validar la visita mediante la Access Control API;
- registrar el resultado sin crear una membresía o cobro local;
- impedir registros duplicados cuando Wellhub reenvíe una notificación;
- mostrar a recepción si la visita fue validada, ya estaba validada, expiró, fue cancelada o no fue encontrada;
- conservar un registro que pueda compararse con el reporte del Portal.

La visita de Wellhub debe permanecer separada de las suscripciones, cortesías y pagos vendidos directamente por el gimnasio. Wellhub administra el plan del usuario y realiza el pago al gimnasio por la visita validada.

## Soporte

Cuando una integración activa presente retrasos, errores de check-in, problemas con el control de acceso o fallas de sincronización, Wellhub indica utilizar su Centro de Ayuda. El reporte debe incluir:

- nombre de la sede;
- Partner ID;
- sistema de gestión utilizado;
- descripción clara del problema.

Los problemas con la cuenta, el plan o la aplicación del usuario corresponden al soporte de Wellhub. La confirmación de presencia y el funcionamiento del acceso físico corresponden al gimnasio y a su sistema integrado.

Fuente: [soporte para integraciones](https://wellhub.com/en-us/partner-academy/cms-integration/) y [responsabilidades de Wellhub y del partner](https://wellhub.com/en-us/partner-academy/what-members-expect/).

## Consecuencias

- FitRoom deberá almacenar el Wellhub ID y la relación entre cada sede y su `gym_id`.
- El sistema dependerá de las credenciales, disponibilidad y reglas operativas de Wellhub.
- El webhook deberá verificar la firma, responder dentro de un segundo y tolerar reintentos sin duplicar registros.
- El personal deberá conocer el flujo normal y la validación manual mediante el Portal de Partners.
- Los pagos seguirán el contrato y los reportes de Wellhub; la integración no modifica la tarifa comercial acordada.

## Alternativa considerada

Operar únicamente desde el Portal de Partners evitaría el desarrollo inicial, pero mantendría la validación manual y la dependencia del personal de recepción. Se conserva únicamente como mecanismo de contingencia, no como solución objetivo.

## Orden de trabajo

1. Confirmar que el Perfil de Empresa de Google esté activo y actualizado.
2. Enviar la solicitud para registrar el gimnasio como partner.
3. Revisar y aceptar las condiciones comerciales ofrecidas por Wellhub.
4. Registrar la cuenta bancaria y completar el perfil de cada sede.
5. Solicitar a Wellhub la guía fiscal aplicable en México.
6. Crear los accesos necesarios para administración y recepción.
7. Solicitar la evaluación del CMS desde `Integrations`.
8. Recibir las credenciales e instrucciones técnicas de Wellhub.
9. Implementar y probar la integración.
10. Obtener la aprobación de Wellhub antes de activar producción.
11. Capacitar al personal en validación normal y contingencia manual.
12. Revisar mensualmente check-ins, reporte de pagos y depósito bancario.

## Fuentes oficiales

- [Wellhub para partners en México](https://wellhub.com/es-mx/partners/)
- [Partner Academy](https://wellhub.com/en-us/partner-academy/)
- [Cómo funciona el proceso de check-in](https://wellhub.com/es-es/partner-academy/proceso-check-in/)
- [Cómo funcionan los pagos](https://wellhub.com/en-us/partner-academy/understand-wellhub-payments/)
- [Portal de Partners](https://wellhub.com/en-us/partner-academy/partner-portal/)
- [Integración de un CMS](https://wellhub.com/en-us/partner-academy/cms-integration/)
- [Estándares de conducta](https://wellhub.com/es-es/partner-academy/estandares-conducta/)
- [Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/getting-started)
- [Endpoints de Access Control API](https://developers.wellhub.com/product/access-control-api/1.0/endpoints)
- [Check-in Webhook](https://developers.wellhub.com/product/access-control-api/1.0/check-in-webhook)
