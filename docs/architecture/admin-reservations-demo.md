# Reservas — vista del administrador (demostración)

- **Estado:** Parte 3 del plan del [ADR 0002](../decisions/0002-perspectiva-administrador-y-reservas.md). Demostración con datos ficticios en memoria y **sin autenticación real** (R11).
- **Reglas:** [reglas de noches y reservas](../business-rules/reservas-y-noches.md) (R1–R8, I11–I17). Este documento describe la implementación; no decide reglas.
- **Base:** [mapa y consulta por noche](reservations-venue-map.md) y [mapa único v7](mapa-noche-de-cristal.md). Comparte el almacén, el controlador y el mapa.

## Navegación

```
Inicio
├── Mapa y disponibilidad        (consulta pública: estados y condiciones, sin datos personales)
└── Administrador (demostración)
    ├── [noche: flechas o deslizar · horario 8:30 p. m.–3:00 a. m.]
    ├── [resumen por estado: tocar filtra el plano]
    ├── Mapa      → ficha de cristal de la mesa
    │               ├── acción corta: Reservar · Ver · Revisar · Ver pago · Actualizar
    │               │   └── reserva directa (mesa libre) o Reserva <ID> (con reserva)
    │               └── abierta: titular, acciones, reservas anteriores
    ├── Reservas  → Pendientes | Reservas (activas y terminadas) | Actividad
    │               └── (cualquier fila) → Reserva <ID>: titular, acciones, actividad
    └── Entradas · Pedidos · Más  → «En desarrollo», sin acción
```

- **Barra inferior:** en el teléfono, la barra de cristal va bajo la ficha. En horizontal o en tableta, ficha y barra van en una columna lateral.
- **Pagos VIP por verificar:** su número aparece sobre «Reservas».
- **Sin datos:** sin datos o con error, la ficha no ofrece reservar. Solo ofrece «Actualizar estado» (reintentar) cuando la consulta falló.
- **Atrás:** el botón Atrás y el del sistema cierran cada ruta en orden.
- **Sin perfiles:** no hay selector de cuentas ni perfiles. El inicio solo avisa de que los datos son ficticios y de que no hay autenticación real.

## Estructura (`lib/features/reservations/`)

| Archivo | Responsabilidad |
|---|---|
| `data/demo_reservation_store.dart` | Almacén único por ejecución (`ChangeNotifier`). `perform` ejecuta una operación del libro y avisa a las vistas. `adminView` devuelve `NightReservations`. |
| `domain/night_availability.dart` | `NightReservations`: estados más reservas de la noche, tomados en la misma consulta. |
| `presentation/venue_map_controller.dart` | Escucha los cambios del almacén (`changes`). Vuelve a consultar la misma noche conservando los datos y la selección; `isRefreshing` lo indica. |
| `presentation/map/` | Mapa único v7, pantalla común, ficha y barra de cristal, compartidos con la consulta pública. |
| `presentation/admin/admin_page.dart` | Pantalla del administrador sobre la pantalla común, la acción de la ficha según el estado, el panel de mesa y las listas. |
| `presentation/admin/reservation_page.dart` | Detalle de una reserva por su ID. Lee del almacén, así que no depende de la noche mostrada. Se repinta al vencer una reserva en proceso, al abrir o cerrar la noche y al volver del segundo plano. |
| `presentation/admin/reservation_actions.dart` | Acciones según el estado, con sus confirmaciones (I13, I14). |
| `presentation/admin/direct_reservation_page.dart` | Formulario de reserva directa (R7). |
| `presentation/admin/admin_labels.dart`, `admin_widgets.dart` | Textos de estados, eventos y errores; tarjeta del titular, historial y filas. |

## Recorridos

| Recorrido | Implementación |
|---|---|
| Reserva directa (R7) | Desde una mesa disponible y una noche no terminada. Pide nombre, cédula y teléfono; cédula y teléfono solo con dígitos, sin longitud ni formato. Teclado numérico o de teléfono. Queda confirmada, también en VIP, con un aviso de verificar el prepago antes. Cancelar no cambia nada y un segundo toque no crea otra reserva. Si la mesa se ocupó o la noche terminó, se explica y no se crea. |
| VIP pendiente (R2) | Confirmar el prepago verificado o rechazar, cada uno con su confirmación. Sin vencimiento. El rechazo queda como evento «rechazada», distinto de «revocada». `NOT DECIDED: proveedor de pagos`. |
| Llegada (R5, N6) | Solo una reserva confirmada de la noche en curso, de 8:30 p. m. a 3:00 a. m. Fuera de ese horario el botón está desactivado y se explica cuándo estará disponible. La operación del dominio no comprueba el rol. |
| Revocar (R4) | Advertencia con la reserva, la mesa, la noche y el titular afectados. |
| Liberar (R6) | Advertencia (que destaca si la mesa está ocupada) y segunda confirmación. Cancelar en cualquier paso no cambia nada. No se borra la reserva: queda terminada con su historial. |
| Pendientes | Sobre todo VIP por verificar. Las normales en proceso se muestran con su hora de vencimiento y sin botón de aprobación; vencen solas también con la vista abierta. |
| Reservas y actividad | Solo lectura. Activas y terminadas (revocadas, rechazadas, liberadas o expiradas), y actividad de la noche en hora de Colombia. Se indica que es una lista local de demostración, no un registro de auditoría. |

## Privacidad

- El nombre, la cédula, el teléfono y el historial del titular solo aparecen en la vista del administrador.
- La consulta pública recibe `NightAvailability`, sin reservas. Sus etiquetas de accesibilidad nombran la mesa y el estado.

## Límites

- Datos en memoria del dispositivo: se pierden al cerrar la app y no se comparten entre dispositivos.
- Sin autenticación ni permisos reales: cualquiera que abra la app entra como administrador de demostración.
- No hay historial de noches ya terminadas en el selector (M2). Una reserva abierta por su ID sigue consultable.
- iOS: solo pruebas del código compartido; la validación nativa está pendiente de macOS/Xcode.
