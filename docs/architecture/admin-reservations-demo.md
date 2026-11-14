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
| Llegada (R5, N6) | Solo una reserva confirmada de la noche en curso, de 8:30 p. m. a 3:00 a. m. Fuera de ese horario el botón está desactivado y se explica cuándo estará disponible. |
| Una salida por estado (P24) | Para no mostrar dos acciones con el mismo efecto: pendiente de pago → «Rechazar solicitud»; Reservada (normal o VIP) → «Revocar reserva»; Ocupada → «Finalizar uso y liberar mesa». El libro sigue admitiendo liberar una Reservada (R6), pero la vista no lo ofrece. No se registra ninguna devolución de prepago. |
| Revocar (R4) | Advertencia con la reserva, la mesa, la noche y el titular afectados. Si el estado cambia con el aviso abierto (por ejemplo, llega el titular), no se aplica y se explica. |
| Finalizar uso y liberar (R6) | Solo con la mesa Ocupada. Advertencia (hacerlo cuando el grupo haya dejado la mesa; no implica devolver pagos) y segunda confirmación. Cancelar en cualquier paso no cambia nada. No se borra la reserva: queda terminada con su historial. |
| Pendientes | Sobre todo VIP por verificar. Las normales en proceso se muestran con su hora de vencimiento y sin botón de aprobación; vencen solas también con la vista abierta. |
| Reservas y actividad | Solo lectura. Activas y terminadas (revocadas, rechazadas, liberadas o expiradas), y actividad de la noche en hora de Colombia. Se indica que es una lista local de demostración, no un registro de auditoría. |
| Registro de actividad (P24, `admin/activity_log.dart`) | Una tarjeta por cambio: icono y tipo, mesa, ID, hora, titular, origen de la reserva y estado actual. La tarjeta no muestra el actor: aunque el historial ya guarda quién confirmó el prepago, rechazó, registró la llegada, revocó o liberó (ver «Actor y cargo»), mostrarlo es un cambio de interfaz pendiente de aprobación; los demás eventos no tienen actor. Agrupada por día y de la más reciente a la más antigua. Búsqueda por mesa, ID o titular; filtros por tipo (solicitudes y altas, confirmaciones, llegadas, cancelaciones y cierres) y por mesa; conteo «N de M», «Quitar filtros» y avisos de vacío o sin coincidencias. Lista perezosa (`ListView.builder`). |

## Actor y cargo de las acciones de reserva (2026-10-20)

- **Quién puede:** «Confirmar prepago verificado», «Rechazar solicitud», «Revocar reserva» y «Finalizar uso y liberar mesa» corresponden a la administración. «Registrar llegada» corresponde a la administración y al mesero (R5). Es la matriz que ya aplicaban las vistas, sin ampliarla.
- **Dónde se comprueba:** la comprueba el propio libro de reservas al ejecutar la acción (`ReservationBook.canPerform`, que inyecta `RumbaapApp.reservationActionAllowed`), después de las confirmaciones y junto a la comprobación de estado. Sin permisos inyectados no se ejecuta ninguna. Un rechazo no cambia el estado ni añade eventos.
- **Qué se guarda:** el evento guarda la identidad activa que ejecutó la acción (`ReservationEvent.actorId`). No se deduce del titular, del origen ni de quien creó la reserva, y `createdBy` no cambia.
- **Sin actor:** no tienen actor los eventos guardados antes de este cambio, la siembra de demostración (`ReservationBook.seedDemoNight`) y el vencimiento automático a los 10 minutos. No se reconstruye.
- **Altas de reserva (2026-10-20):** cada alta comprueba el permiso antes de tocar la mesa (`ReservationBook.canCreate`, que inyecta `RumbaapApp.reservationCreationAllowed`) y guarda su actor en el evento. Un alta denegada no crea nada, no ocupa la mesa ni consume número de reserva. La matriz sale de cada flujo vigente; no es la de las cinco acciones:

  | Alta | Quién | Regla | Actor del evento | Creador (`createdBy`) |
  |---|---|---|---|---|
  | Iniciar el trámite normal (`startNormal`) | Cliente (origen cliente) y promotor (origen promotor) | R1, R14 | `requested` = quien lo inicia | Quien lo inicia |
  | Enviar el trámite (`submitNormal`) | Solo quien lo inició, con su mismo perfil | R13, R14 | `completed` = quien lo envía | Sin cambios |
  | Salir y cancelar el trámite (`cancelInProcess`) | Solo quien lo inició | R15 | `cancelled` = quien sale | Sin cambios |
  | Solicitud VIP (`submitVip`) | Cliente (origen cliente) y promotor (origen promotor) | R16, R2 | `requested` = quien la envía | Quien la envía |
  | Reserva directa (`createDirect`) | Administración | R7 | `createdDirect` = quien la crea | Vacío, como antes (no es una solicitud propia) |
  | Personal (Seguridad, Caja, Barra, Mesero) | No crea reservas | — | — | — |

  El trámite normal y la solicitud VIP rechazan el origen administrativo con una excepción de dominio (`notAllowed`), también para la administración y con los asserts desactivados (C1, revisión de Codex): ese origen solo entra por `createDirect`.

  El titular (`holder`) es siempre aparte: el nombre que se escribe en el formulario. La cuenta vinculada (`linkedAccountId`) no convierte a nadie en creador. Un trámite sin creador (siembra o datos anteriores) no lo envía ni lo cancela nadie: vence solo (R1).
- **Siembra separada de las altas:** las antiguas rutas sin actor (`requestNormal`, `completeRequest`, `requestVip`) se retiraron. La siembra es un único método, `seedDemoNight`, que solo rellena una noche vacía y no terminada, con las mismas comprobaciones de mesa y noche. La carga de snapshots (`importState`) restaura lo guardado, sin pasar por las altas.
- **Fuera de este cambio (`NOT DECIDED` o pendiente):** la lógica no comprueba la ventana de noches por perfil (N5: el cliente, la semana en curso; N7: el promotor, también futuras); la limita el selector de noches de cada vista.
- **Persistencia:** clave opcional `actorId` en cada evento. Los datos anteriores cargan sin cambios y sin actor, y el formato no cambia de versión.
- **Límite:** son identidades ficticias. Comprobar el cargo no equivale a autenticación ni a autorización real de un backend.

## Privacidad

- El nombre, la cédula, el teléfono y el historial del titular solo aparecen en la vista del administrador.
- La consulta pública recibe `NightAvailability`, sin reservas. Sus etiquetas de accesibilidad nombran la mesa y el estado.

## Límites

- Datos ficticios guardados solo en este teléfono (persistencia local de la demo, ver `perfiles-demo.md`); no se comparten entre dispositivos.
- Sin autenticación ni permisos reales: cualquiera que abra la app entra como administrador de demostración.
- No hay historial de noches ya terminadas en el selector (M2). Una reserva abierta por su ID sigue consultable.
- iOS: solo pruebas del código compartido; la validación nativa está pendiente de macOS/Xcode.
