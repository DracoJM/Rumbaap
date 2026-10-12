# Entradas, credenciales y manillas (prototipo P25)

- **Estado:** prototipo frontend con datos ficticios y pagos SIMULADOS. No hay backend, cobro, devolución de dinero, lector ni autenticación reales.
- **Código:** `lib/features/tickets/` (dominio `TicketBook`, almacén `DemoTicketStore`, vistas de cliente, promotor, puerta, taquilla y administración).
- **Leyenda:** `VALIDATED` (indicado por el equipo), `PROPUESTA` (recomendación técnica pendiente de ratificar por Juanmi), `NOT DECIDED`.

## Recorrido

| Paso | Quién | Qué ocurre | Estado |
|---|---|---|---|
| Venta | Cliente (app) o promotor | Crea derechos sin activar y sin credencial. Mostrar una venta no activa nada. | VALIDATED |
| Pago | Cliente: pago simulado. Promotor: confirma el pago comprobado de su venta. | Solo entonces el derecho se activa y se emite la credencial. | VALIDATED |
| Cortesía | Administración | Activa sin pago, con nombre y motivo (p. ej. mesa VIP). La cantidad la decide quien autoriza. | VALIDATED (cortesías VIP); cantidad: 6 por mesa VIP como beneficio de su reserva ([beneficios VIP](beneficios-vip.md)); fuera de ese beneficio, NOT DECIDED |
| Consulta de puerta | Seguridad | Muestra el estado vigente para este local y la noche en curso, y los datos del registro. No cambia nada. | PROPUESTA |
| Primer ingreso | Seguridad | «Confirmar primer ingreso» lo registra una vez. Un segundo intento muestra «Ingreso ya registrado» y no bloquea la taquilla. | PROPUESTA |
| Canje | Taquilla (app y cortesías) o promotor con su lote (sus ventas) | Entrega la manilla una vez. Después, puerta y taquilla responden «No canjeable». El reingreso es con la manilla. | VALIDATED (canje único, reingreso con manilla); separación de pasos: PROPUESTA |
| Rechazo | Puerta o taquilla | Motivo visible e incidencia con actor y hora. Nunca revoca un derecho válido en su contexto (otra noche u otro local). | VALIDATED |

- **Circuitos.** Taquilla canjea compras de la app y cortesías. Las ventas del promotor se canjean con su lote físico; activar su credencial no traslada esa custodia a taquilla.
- **Precio.** Por noche, de DEMOSTRACIÓN (`TicketProduct.demoPriceByWeekday`); no es la política del local. Precios y eventos reales: NOT DECIDED.
- **Aforo.** Configurable por local (`VenueConfig.capacity`), hoy sin configurar. La ocupación física no se deduce de entradas ni de ingresos.

## Credencial (lo que lleva el QR)

- **Pedido de Juanmi:** borrar y reutilizar identificadores al canjear; y tener nombre y cédula disponibles al validar.
- **PROPUESTA implementada en la demo, pendiente de ratificar:**
  - Credencial **nueva de longitud fija** (12 caracteres: prefijo de 2 del local y 10 aleatorios de un alfabeto sin ambigüedades). Los 12 caracteres son una decisión de DEMO, no una garantía de seguridad de producción: emitirlas y verificarlas será responsabilidad del backend.
  - Se generan al azar y no a partir de un contador, para que tras reiniciar la demo no vuelvan a salir las mismas (lo detectó el recorrido en Android).
  - Al reemplazarla (cliente o administración) o anularla, la anterior queda **retirada y no se recicla**. Leerla después da «Credencial retirada». La venta, el pago y la cuenta se conservan.
  - El QR es una **referencia opaca**: no lleva nombre, cédula ni estado. La puerta obtiene nombre y cédula del registro («Datos del registro, no de la captura»), mediante un lector autorizado en el sistema real.
  - Diferencia con el pedido: los identificadores no se reutilizan, para que una captura antigua nunca vuelva a ser válida y se conserve la trazabilidad.
- **Límite que sigue vigente:** un QR vigente compartido puede usarlo primero otro portador. La comprobación física de la persona sigue siendo necesaria.
- **Demo:** la ficha de la entrada muestra un QR real que codifica solo la credencial vigente. Puerta, Caja y el promotor (su lote) lo leen con la cámara, que activa el personal con su botón, o escriben la credencial a mano como respaldo. La lectura solo consulta: el primer ingreso y el canje siguen necesitando la confirmación de la persona. Detalle en [QR y cámara](../proposals/qr-escaneable-y-camara.md).
- **«Mi QR» del cliente:** es el mismo QR real de su entrada de la noche en curso; no hay otro código de cuenta. Con varias entradas propias esa noche, la persona elige cuál mostrar (un QR a la vez; no se crea, fusiona ni transfiere nada, y no implica una política de compras múltiples). La elección se descarta si cambian la cuenta, el local o la noche, o si la entrada deja de estar disponible. Sin entrada, lo dice. Barra lo usa solo para identificar la cuenta (ver [pedidos de barra](pedidos-barra.md)).

## Devoluciones y cambios

- El cliente solicita la devolución o el cambio a otra noche de una entrada activa, sin primer ingreso.
- Solo la administración autoriza o rechaza.
- Una devolución autorizada anula la entrada y retira su credencial. NO devuelve dinero.
- La «devolución efectuada» se registra aparte, cuando ocurre fuera de la app.
- Las cortesías no admiten solicitudes.
- Reembolso VIP, grupos y transferencia digital: no se definen aquí (NOT DECIDED).

## Frontera para el backend futuro

- `TicketGateway` (puerta y taquilla): operaciones asíncronas e idempotentes por `requestId`. Un reintento con el mismo identificador devuelve el mismo resultado sin repetir la operación ni la incidencia.
- La interfaz distingue «consultando», éxito, rechazo y fallo de conexión. Ante un fallo, reintenta con el mismo identificador.
- El backend deberá autorizar cada operación según el rol y registrar cada paso de forma indivisible. La demo vive en memoria en un solo dispositivo: NO hay concurrencia real entre dispositivos.

## Registro y actores

- Cada operación nueva guarda el actor (identidad ficticia), la hora, la nota o el motivo, y el origen y el importe de la venta.
- No se reconstruyen actores desconocidos.
