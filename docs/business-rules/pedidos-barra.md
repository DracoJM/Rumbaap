# Pedidos de barra y comprobantes de consumo (prototipo)

- **Estado:** prototipo frontend con datos ficticios. El pago es PRESENCIAL y SIMULADO: la app no cobra. No hay inventario, tienda de licor, beneficios, niveles ni puntos.
- **Código:** `lib/features/bar/` (dominio `BarBook`, almacén `DemoBarStore`, vistas en `bar_views.dart`).
- **Leyenda:** `VALIDATED` (indicado por el equipo), `NOT DECIDED`.

| Quién | Qué hace | Estado |
|---|---|---|
| Cliente | Consulta el menú (informativo, con precios de demostración) y sus comprobantes de consumo. No compra en la app. | VALIDATED |
| Barra | Registra una compra ya pagada en persona. Sin confirmar el pago completo no se registra nada. Puede vincular la venta a una mesa con reserva de la noche y a la cuenta del cliente, identificada con el QR de su entrada de la noche (cámara o credencial escrita); el cliente recibe el comprobante. | VALIDATED |
| Caja y administración | Corrigen una venta (quitar unidades o anularla) con motivo y confirmación. Queda lo anterior, quién lo hizo y cuándo; anular no borra. Subir una cantidad o añadir un producto se rechaza sin cambiar la venta ni su historial. | VALIDATED |
| Mesero | Consulta las ventas de barra de cada mesa reservada de la noche y acepta el consumo a mano, con nota opcional. Se guarda lo que vio (ventas y suma). Si después cambian las ventas, la ficha lo avisa. | VALIDATED |

- **Estados distintos:** reserva, entrada, compra/pago/entrega en barra y aceptación del consumo son estados distintos. La suma de ventas es informativa; nada se declara cumplido automáticamente.
- **Mesa VIP con prepago (aprobado por el usuario, 2026-10-12):**
  - Cada mesa VIP tiene un consumo prepagado de 2.000.000 COP (importe de `TableTerms.prepaidConsumption` del local). La administración lo registra EXPRESAMENTE en la ficha de la reserva tras verificarlo; no se deduce de prepagos anteriores: sin registro, la mesa queda «prepago sin registrar» y barra no consume ni cobra como pago completo.
  - Barra consume contra el saldo y solo cobra el excedente, con la confirmación del pago presencial completo de la diferencia. Ejemplos: 1.500.000 → no se cobra nada, saldo 500.000; 2.300.000 → se cobran solo 300.000. Nunca se vuelven a cobrar los 2.000.000. Cada venta guarda lo aplicado del prepago y lo cobrado; el saldo se calcula de las ventas, sin doble descuento.
  - El saldo no consumido al terminar esa noche se pierde: sin devolución ni traslado automático.
  - Cancelación o no llegada: el prepago solo puede aplicarse a otra noche por acuerdo directo con la administración. La app muestra esa gestión manual pendiente; no devuelve, no vence ni traslada automáticamente ese caso.
  - Corregir o anular una venta contra prepago (qué pasa con el saldo y con el excedente cobrado): NOT DECIDED. La demo no permite corregirlas y no registra devoluciones de dinero.
  - Validación en `BarBook.register` (local con sus mesas obligatorio): reserva y mesa juntas, la mesa existe en el local; en mesa VIP, el prepago registrado debe ser de esa mesa y de la noche en curso. No comprueba que la reserva exista ni que corresponda a esa mesa: lo resuelve la vista de barra, que solo ofrece reservas vigentes de la noche con su mesa.
  - Mesero, cliente (su reserva) y administración ven prepago, consumido, saldo y excedente cobrado.
- **Consumo de referencia:** se muestran las condiciones de la mesa (p. ej. el consumo de referencia de Sagsa), sin calcular si se cumplió.
- **Menú y precios:** de demostración, en `VenueConfig.menu`. Carta y precios reales: NOT DECIDED.
- **Pago presencial:** medio de pago y verificación real: NOT DECIDED.
- **Privacidad:** el cliente solo ve las ventas vinculadas a su cuenta. Barra no ve los datos de la cuenta al vincularla.
- **Identificación en barra (demo, 2026-10-12):** un solo QR para identidad y entrada. Barra consulta `TicketGateway.identifyAccount`: la cuenta sale del registro de la entrada, nunca del QR. Solo consulta: no registra ingreso ni canje ni anota incidencias.
  - Identifica la credencial vigente de una entrada de este local para la noche en curso, también ya canjeada (sigue «No canjeable» en puerta y taquilla).
  - No identifica una credencial retirada, de otra noche o de otro local, ni una entrada anulada. Una entrada sin cuenta (promotor o cortesía) lo dice: la venta se registra sin comprobante.
  - No existe un código de cuenta permanente: una captura de otra noche no identifica ni canjea nada.
  - Con el campo vacío la venta se registra sin comprobante, como antes. Las ventas ya guardadas conservan su cuenta.
- **Persistencia:** las ventas, las correcciones y las aceptaciones se guardan con el resto de la demo (sección `bar` del estado guardado).

## Cliente sin cuenta, credencial y mesa (2026-10-12)

| Elemento | Estado |
|---|---|
| Barra puede registrar la venta de un cliente **sin app**, con o sin datos. | VALIDATED (pedido de Juanmi) |
| Opción «Cliente sin cuenta» con nombre, teléfono y cédula **opcionales**; sin datos, la venta queda como «Cliente sin identificar». Es un contacto manual **no verificado**, guardado en la venta y separado de la cuenta: no crea cuenta ni da acceso, beneficios o puntos y no se vincula solo por coincidir cédula o teléfono. | VALIDATED (pedido de Juanmi); campos opcionales y su presentación: DECISIÓN DE PROTOTIPO |
| Cuenta identificada por credencial y cliente sin cuenta son excluyentes; al cambiar de modo se descarta el código o el contacto del borrador. Teléfono y cédula solo admiten dígitos. | DECISIÓN DE PROTOTIPO |
| Precio, total, cobrado, prepago/excedente y correcciones no dependen de la identidad del cliente. | Comportamiento existente conservado |
| Consolidación de estos contactos con cuentas reales, y puntos. | NOT DECIDED |
| El campo se llama «Credencial» («Escribe o pega el ID del cliente»); «Escribir la credencial» en el lector lleva el foco al campo, y cancelar el lector no. | DECISIÓN DE PROTOTIPO (texto) |
| El selector de mesa sigue mostrando solo las reservas confirmadas u ocupadas de la noche en curso, y explica el vacío (sin noche en curso, o sin reservas confirmadas). «Sin mesa» sigue disponible. | DECISIÓN DE PROTOTIPO |
