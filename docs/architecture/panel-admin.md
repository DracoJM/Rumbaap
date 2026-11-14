# Panel de la administración (frontend de demostración)

- **Dónde:** Administración → «Más» → «Panel de la administración» (`lib/features/dashboard/dashboard_page.dart`).
- **Alcance:** un local; una noche o todo el período con datos. Se muestran la fuente (datos ficticios de este teléfono), el corte (hora de consulta) y la cobertura (primera y última noche con datos).

| Bloque | Indicadores | Nota |
|---|---|---|
| Personas | Primeros ingresos con entrada; manillas canjeadas; entradas vigentes sin canjear; reservas con llegada | No se suman entre sí: una persona puede tener entrada y reserva. Sin salidas registradas no se calcula ocupación actual ni permanencia. |
| Importes (COP de demostración) | Entradas pagadas; devoluciones autorizadas (aparte, sin restar en silencio); cobrado en barra (dinero recibido, incluido el excedente sobre el prepago VIP); prepagos VIP verificados (solo cantidad); consumo VIP contra prepago (aparte, con los prepagos registrados y su importe; no se suma a lo cobrado); ingresos de productos registrados asociados a esta noche = prepagos VIP con importe registrado de esa noche + cobrado en barra (2.000.000 + 300.000 = 2.300.000 en el caso de 2.300.000 de consumo; no es la caja recibida hoy ni contabilidad por fecha), con los pendientes aparte (VIP aprobadas sin importe registrado y gestión manual), sin declarar un cierre financiero completo. También es parámetro de meta. | Las cortesías no tienen importe. El prepago VIP no se suma a las ventas de barra para no contarlo dos veces. Son ingresos, no rentabilidad: no hay costos. |
| Operación | Reservas; reservas VIP con beneficios ([reglas](../business-rules/beneficios-vip.md)); consumos aceptados por mesero; incidencias de puerta y taquilla | Cada uno abre su lista. Al filtrar una noche, una incidencia cuenta en la noche operativa en curso cuando se hizo la lectura, tenga o no entrada asociada; la ficha de la incidencia muestra aparte la noche de la entrada (p. ej. una entrada del viernes leída el sábado). Las lecturas fuera de horario no se asignan a ninguna noche: solo aparecen en todo el período. |

- **Resumen de la noche:** solo con una noche elegida (no para todo el período). Texto revisable con local, noche operativa y año, corte y cobertura; personas, importes, metas (mismo texto que las tarjetas), incidencias por motivo y beneficios VIP con lo pendiente de regla. Solo cifras agregadas: sin nombres, cédulas, cuentas ni credenciales. Se copia al portapapeles únicamente con «Copiar resumen», que avisa del éxito o del fallo; no genera archivos.
- **Navegación:** cada indicador abre su lista, y cada elemento abre su ficha (entrada, venta de barra o reserva).
- **Metas (demo, 2026-10-12):** opcionales, por local y noche; no hay metas para todo el período ni valores por defecto. La administración las configura, edita y quita (con actor y hora) en cuatro parámetros, cada uno un indicador existente con su definición y su detalle:
  - Asistencia registrada: primeros ingresos con entrada (personas) y reservas con llegada registrada (reservas). No se suman entre sí y no son aforo ni ocupación.
  - Ingresos registrados (COP): entradas pagadas y ventas de barra vigentes. El prepago VIP no entra (se cuenta sin importe) y las devoluciones se muestran aparte.
  - Avance por parámetro, sin puntuación ni resultado global. «Sin configurar» si no hay meta. Con la noche en curso o sin empezar el avance es parcial y no se afirma un resultado; con la noche terminada se indica si se alcanzó.
  - Se validan como enteros mayores que cero. Se guardan en la sección opcional `goals` del estado; los datos anteriores sin ella cargan sin metas. Una noche con meta y sin movimientos sigue en el selector.
- **IA:** los registros guardan hora y actor para un análisis futuro. No hay predicciones ni se simulan.
- **Acciones:** la administración las decide fuera de la app.
