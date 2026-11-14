# Plan del siguiente incremento: diseño y navegación, y reserva del promotor

> **Nota de vigencia (2026-10-12):** antecedente histórico y `HYPOTHESIS`. Describe un plan del 10 de octubre que ya se ejecutó o fue sustituido (ADR 0004 y 0005). NO es una orden vigente ni convierte sus propuestas en requisitos. Para retomar, ver [`continuacion-claude.md`](continuacion-claude.md).

> **Nota (10/10/2026):** el estilo de la entrega 1 (ADR 0003) quedó sustituido por el [ADR 0004](decisions/0004-mapa-unico-noche-de-cristal.md). La entrega aprobada P22/P22.1 implementó el mapa único v7 compartido por la consulta y el administrador; ver [mapa-noche-de-cristal.md](architecture/mapa-noche-de-cristal.md). El resto del plan sigue como `HYPOTHESIS`.

- **Estado del plan:** `HYPOTHESIS`. Es la propuesta de ejecución de Claude, todavía sin aprobar ni implementar. Las reglas en las que se apoya sí están aprobadas.
- **Base:** la Parte 3 (rama `feat/admin-reservations-demo`), cuando se apruebe y se guarde en su commit. Hasta entonces no se empieza ninguna entrega.
- **Leyenda:**
  - **[Aprobado]** es una regla o decisión del equipo, con su fuente.
  - **[Propuesta de Juanmi]** es la navegación del punto 4 del 10 de octubre, adoptada como alcance de la entrega 1.
  - **[Propuesta de Claude]** es una forma de implementarla, a revisar con este plan.

## 1. Lo aprobado en que se apoya

| Tema | Fuente |
|---|---|
| Titular del promotor: nombre y teléfono obligatorios, cédula opcional, sin adjudicación automática a cuentas ni puntos | [R12](business-rules/reservas-y-noches.md) |
| Completar el trámite: resumen y envío final; la normal se confirma, la VIP queda pendiente de pago sin caducidad | [R13](business-rules/reservas-y-noches.md), R1–R3, R7 |
| Noches del promotor: el selector del administrador, incluidas las futuras; sin acciones ni datos del administrador | [N7](business-rules/reservas-y-noches.md) |
| Reserva directa del administrador: nombre, cédula y teléfono obligatorios (sin cambios) | R7 |
| Dirección visual Noche contemporánea y área VIP «un cuarto menos» | [ADR 0003](decisions/0003-direccion-visual-noche-contemporanea.md) |

El modelo ya admite al promotor, sin cambios de datos para el titular:
- `ReservationHolder` tiene la cédula y el teléfono opcionales;
- `ReservationOrigin.promoter` existe;
- `requestNormal`, `completeRequest` y `requestVip` aceptan ese origen.

La búsqueda y vinculación a cuentas por cédula queda como capacidad futura del modelo. **No se propone una vinculación simulada:** sin un directorio real de clientes, cualquier coincidencia sería inventada. El resumen y el administrador mostrarán «Sin cuenta vinculada».

## 2. Entrega 1: diseño y navegación

Es solo de presentación. No toca el dominio, el almacén ni las reglas.

**Navegación [Propuesta de Juanmi]:**
1. La entrada «Mapa y disponibilidad» del inicio pasa a llamarse **«Cliente (demostración)»**, con la marca **«Solo consulta»** visible en el inicio y en la cabecera del mapa.
2. El mapa del cliente muestra la disponibilidad y el detalle de las mesas, sin nombres, cédulas ni teléfonos (como ahora). No muestra un botón Reservar.
3. El administrador conserva su mapa y sus acciones.
4. No se añade la entrada del promotor hasta la entrega 2.
5. Hay un solo componente de mapa con un solo almacén. No se crean mapas con datos o reglas separados.

**Estilo [Aprobado, ADR 0003]:**
- Paleta y acabado Noche contemporánea en el dibujo del recinto (`VenuePainter`) y del mobiliario (`TableFurniturePainter`). Se aplica a cliente y administrador, porque comparten el componente.
- Mobiliario VIP dibujado a escala 0,75 dentro de la caja de 184.
- Tarima visible de (180, 20) a (820, 182).
- Todo lo demás conserva su geometría.

**Ajustes que provoca la tarima más baja [Propuesta de Claude]:**
- **Puffs.** Hoy se dibujan a 18 unidades del borde inferior de la tarima y se solaparían con el mueble reducido. Se recolocarán según la referencia.
- **Caja táctil VIP.** Con 184 de lado alrededor de y = 112, llega hasta y = 204, por debajo del borde visible (182). Se mantiene así, como pide el ADR, para no empeorar el acceso. No se solapa con las escaleras ni con otras mesas.
- **Etiqueta y badge.** El tamaño de la etiqueta y del badge VIP no se reduce.
- **Decoración de la tarima.** Las líneas de tarima y el rótulo «ZONA VIP» se recalculan desde la tarima visible.

**Pruebas:**
- Geometría:
  - las 22 mesas conservan sus IDs y centros, y las VIP su caja de 184;
  - el dibujo VIP sale a escala 0,75;
  - la tarima visible mide 640 × 162, con el borde norte intacto.
- Widgets, con `TargetPlatformVariant.mobile()`:
  - las entradas del inicio y la marca «Solo consulta»;
  - el mapa del cliente no tiene acciones ni datos personales;
  - el tap y la semántica siguen funcionando en las VIP.
- Móvil pequeño, horizontal y texto al 200 % sin desbordes.
- Animación: pausa y reducción de movimiento (tests existentes).
- `dart format`, `flutter analyze` y `flutter test`.
- APK debug en el emulador, con capturas comparadas a ojo con la referencia. No se presentan como validación de diseño.

**Referencias:** están fuera de Git, en `C:\Users\draco\Projects\Rumbaap-referencias\`. Son diseños, no capturas de la app.
- **SVG:** el archivo se llama `Rumbaap_noche_contemporanea (1).svg`. Es XML válido, con `viewBox` de 1060 × 1640.
- **PNG:** `Rumbaap_noche_contemporanea.png`, de 1060 × 1640.

## 3. Entrega 2: reserva del promotor por nombre

**Recorrido [Aprobado: N7, R12–R16; pantallas propuestas por Claude]:**
1. **Entrada.** El inicio añade «Promotor (demostración)», con un aviso de datos ficticios y sin autenticación real (como R11).
2. **Noche y mesa.** El promotor elige la noche en el selector del administrador (N7) y una mesa en el mapa compartido. Ve los estados de las mesas, nunca los titulares ni los datos de reservas ajenas.
3. **Iniciar.** Desde el panel de una mesa reservable, el promotor pulsa «Reservar esta mesa». En una normal empieza el trámite y su cuenta atrás (R14); en una VIP solo se abre el formulario (R16). Seleccionar la mesa no inicia nada (R13).
4. **Datos del titular.**
   - Formulario: nombre y teléfono obligatorios, cédula opcional (R12).
   - Teléfono y cédula, si se escribe, solo admiten dígitos. Se valida a la vista, como I17.
   - El formulario del administrador no cambia.
5. **Resumen.** Muestra la noche, la mesa y su tipo, el titular, «Sin cuenta vinculada», y qué ocurrirá: confirmación inmediata (normal) o «Pendiente de pago/verificación» (VIP).
6. **Envío.** Con el botón final, la app vuelve a validar los datos y la disponibilidad.
   - **Normal:** queda Reservada, con origen Promotor.
   - **VIP:** queda pendiente de pago y aparece en «Pendientes» del administrador.
   - Si la mesa dejó de ser reservable, se muestra un error claro y no se crea nada.
7. **Resultado.** Una pantalla muestra el ID y el estado de lo que acaba de crearse. No hay una lista «Mis reservas», porque requeriría identificar al promotor.

**Decisiones del prototipo [Aprobado: R14, R15, R16]:**
- **Normal.** Al pulsar «Reservar esta mesa», el almacén crea un trámite provisional con noche, mesa, origen e ID, sin titular. El trámite bloquea la mesa 10 min desde ese inicio. El titular se exige al enviar, y el envío solo confirma si el trámite sigue activo y sin vencer.
- **Abandono.** Salir expresamente del recorrido, tras una confirmación breve, cancela el trámite normal activo y libera la mesa. Volver del resumen o pasar la app a segundo plano no cancela nada.
- **VIP.** La solicitud se crea solo al enviar, y el almacén vuelve a comprobar la disponibilidad. Salir antes de enviar no deja nada pendiente. Salir después no cancela la solicitud.

**Cambio de modelo [Propuesta de Claude: la más pequeña que veo]:**
- **Regla del titular [corrección de Juanmi, 2026-10-10]:**
  - **Normal sin enviar.** Un trámite normal todavía no enviado puede no tener titular mientras está En proceso, Cancelado o Expirado. Si se cancela o vence, conserva su ID, mesa, noche, origen y el motivo en el historial, aunque no haya titular.
  - **Envío.** El titular se valida y se registra en la misma operación que confirma la normal o crea la solicitud VIP.
  - **Reserva ya enviada.** Conserva su titular completo en todos los estados posteriores. Una VIP Pendiente de pago/verificación siempre lo tiene.
  - **Límite de la excepción.** No permite crear sin titular una VIP, una reserva directa ni una reserva confirmada.
  - **Titular completo:**
    - para el promotor, nombre y teléfono válidos, con la cédula opcional (solo dígitos si se escribe);
    - para la reserva directa del administrador, los tres campos obligatorios (R7).
- **Técnica [Propuesta de Claude, hasta revisar la implementación]:**
  - **`requestNormal`:** ya no pide el titular, solo noche, mesa y origen.
  - **`completeRequest(id, holder)`:** recibe el titular, lo valida y confirma en una sola operación. Si el trámite ya venció, se canceló o no está En proceso, falla sin efectos (I8).
  - **`requestVip` y `createDirect`:** siguen exigiendo un titular válido para crear.
  - **`cancelRequest(id)` (nueva):** solo vale para un trámite normal En proceso. Lo cierra en el estado inactivo nuevo **Cancelada**, con su evento en el historial, y no afecta a reservas confirmadas ni a VIP enviadas. Cancelada es distinta de Expirada (vencimiento) y de Revocada (acción del administrador), y no da al promotor acciones administrativas. Juanmi lo considera adecuado.
  - **Comprobación en el dominio:** el titular solo puede faltar en un trámite normal no enviado (En proceso, Cancelada o Expirada).
- **Qué ve cada perspectiva:**
  - **Administrador, bandejas e historial:** muestran el trámite sin titular («En proceso», «Cancelada» o «Expirada») con un texto neutro tipo «Trámite sin titular registrado», sin inventar un cliente.
  - **Mapa público:** igual que hoy, sin datos personales.

**Pruebas:**
- Dominio:
  - reserva del promotor con y sin cédula;
  - nombre y teléfono obligatorios;
  - el trámite normal provisional sin titular: bloqueo en el almacén, plazo desde el inicio, envío tras el vencimiento rechazado sin efectos;
  - cancelación solo del trámite normal activo (no de confirmadas ni VIP);
  - VIP creada solo al enviar, con nueva comprobación de disponibilidad;
  - la normal confirmada no vence;
  - la VIP queda pendiente sin caducidad;
  - la mesa ya tomada da un error sin efectos.
- Regresiones obligatorias del modelo sin titular:
  1. Cancelar un trámite normal sin titular lo deja inactivo y libera la mesa.
  2. Vencer un trámite normal sin titular lo deja expirado y libera la mesa.
  3. Enviar un trámite ya cerrado (cancelado o expirado) se rechaza sin confirmar nada.
  4. No se puede crear sin un titular válido una reserva enviada ni una VIP pendiente.
  5. La vista del administrador y el historial muestran un trámite sin titular sin fallar y sin inventar un cliente.
- Widgets en Android e iOS (código compartido):
  - el recorrido completo, normal y VIP;
  - la validación a la vista;
  - el resumen;
  - el promotor no ve acciones del administrador ni datos ajenos;
  - el administrador ve el origen Promotor y la VIP en «Pendientes»;
  - el mapa del cliente se actualiza sin datos personales.
- Móvil pequeño, horizontal y texto al 200 %.
- Checks y APK con recorrido real.

**Fuera de alcance:**
- autenticación;
- búsqueda o vinculación de cuentas;
- puntos y pagos reales;
- eventos del promotor y gestión de promotores;
- el recorrido de reserva del cliente;
- backend y persistencia;
- nuevas dependencias.

## 4. Orden y control

1. Revisar el ZIP de la Parte 3 y aprobar su commit (base). Después, el commit de la configuración de Claude Code (`.claude/` y `.gitignore`), que va en segundo lugar porque la skill enlaza documentos que entran con la Parte 3.
2. Entrega 1 en su propia rama desde esa base. Revisión, y commit solo con aprobación.
3. Entrega 2 en otra rama desde la entrega 1 aprobada. Revisión, y commit solo con aprobación.

En ningún caso se hace push, merge ni rebase.
