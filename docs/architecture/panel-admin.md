# Panel de la administración (frontend de demostración)

- **Dónde:** Administración → «Más» → «Panel de la administración» (`lib/features/dashboard/dashboard_page.dart`).
- **Alcance:** un local; una noche o todo el período con datos. Se muestran la fuente (datos ficticios de este teléfono), el corte (hora de consulta) y la cobertura (primera y última noche con datos).

| Bloque | Indicadores | Nota |
|---|---|---|
| Personas | Primeros ingresos con entrada; manillas canjeadas; entradas vigentes sin canjear; reservas con llegada | No se suman entre sí: una persona puede tener entrada y reserva. Sin salidas registradas no se calcula ocupación actual ni permanencia. |
| Importes (COP de demostración) | Entradas pagadas; devoluciones autorizadas (aparte, sin restar en silencio); ventas de barra vigentes; prepagos VIP verificados (solo cantidad) | Las cortesías no tienen importe. El prepago VIP no se suma a las ventas de barra para no contarlo dos veces. Son ingresos, no rentabilidad: no hay costos. |
| Operación | Reservas; consumos aceptados por mesero; incidencias de puerta y taquilla | Cada uno abre su lista. |

- **Navegación:** cada indicador abre su lista, y cada elemento abre su ficha (entrada, venta de barra o reserva).
- **Metas:** mecanismo propuesto, sin metas configuradas. No se muestran umbrales ni índices de éxito.
- **IA:** los registros guardan hora y actor para un análisis futuro. No hay predicciones ni se simulan.
- **Acciones:** la administración las decide fuera de la app.
