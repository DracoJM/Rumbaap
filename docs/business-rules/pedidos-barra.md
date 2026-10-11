# Pedidos de barra y comprobantes de consumo (prototipo)

- **Estado:** prototipo frontend con datos ficticios. El pago es PRESENCIAL y SIMULADO: la app no cobra. No hay inventario, tienda de licor, beneficios, niveles ni puntos.
- **Código:** `lib/features/bar/` (dominio `BarBook`, almacén `DemoBarStore`, vistas en `bar_views.dart`).
- **Leyenda:** `VALIDATED` (indicado por el equipo), `NOT DECIDED`.

| Quién | Qué hace | Estado |
|---|---|---|
| Cliente | Consulta el menú (informativo, con precios de demostración) y sus comprobantes de consumo. No compra en la app. | VALIDATED |
| Barra | Registra una compra ya pagada en persona. Sin confirmar el pago completo no se registra nada. Puede vincular la venta a una mesa con reserva de la noche y a la cuenta del cliente por su QR personal (lectura simulada); el cliente recibe el comprobante. | VALIDATED |
| Caja y administración | Corrigen una venta (quitar unidades o anularla) con motivo y confirmación. Queda lo anterior, quién lo hizo y cuándo; anular no borra. | VALIDATED |
| Mesero | Consulta las ventas de barra de cada mesa reservada de la noche y acepta el consumo a mano, con nota opcional. Se guarda lo que vio (ventas y suma). Si después cambian las ventas, la ficha lo avisa. | VALIDATED |

- **Estados distintos:** reserva, entrada, compra/pago/entrega en barra y aceptación del consumo son estados distintos. La suma de ventas es informativa; nada se declara cumplido automáticamente.
- **Consumo de referencia:** se muestran las condiciones de la mesa (p. ej. el consumo de referencia de Sagsa), sin calcular si se cumplió.
- **Menú y precios:** de demostración, en `VenueConfig.menu`. Carta y precios reales: NOT DECIDED.
- **Pago presencial:** medio de pago y verificación real: NOT DECIDED.
- **Privacidad:** el cliente solo ve las ventas vinculadas a su cuenta. Barra no ve los datos de la cuenta al vincularla.
- **Persistencia:** las ventas, las correcciones y las aceptaciones se guardan con el resto de la demo (sección `bar` del estado guardado).
