# Perfiles y sesiones de demostración (P23)

- **Estado:** prototipo con **identidades ficticias**, sin contraseñas ni autenticación real (`NOT DECIDED: autenticación`). La cédula identifica una cuenta ficticia; nunca es una contraseña.
- **Base:** [ADR 0004](../decisions/0004-mapa-unico-noche-de-cristal.md) (mapa único v7) y [reglas de noches y reservas](../business-rules/reservas-y-noches.md).

## Entrada

`lib/app/home_page.dart` muestra las identidades de `lib/features/session/demo_identities.dart`, agrupadas por perfil: Cliente (A y B), Promotor, Administración y Personal.

- Elegir una identidad abre su propia navegación sobre la entrada.
- Volver, o «Cambiar identidad» en «Más», hace `popUntil(isFirst)`: se descarta la pila de esa sesión, con sus formularios y los titulares que mostraba.
- Desde un trámite, «Cambiar identidad» (barra superior) es una salida más: con una normal En proceso pide la misma confirmación que «atrás». Seguir conserva el formulario y el plazo; salir la cancela (R15) y limpia la pila. Una VIP ya enviada no se toca.
- Las reservas siguen en el **único almacén del local** (`DemoReservationStore`), compartido por todos los perfiles.

## Navegación por perfil

| Perfil | Pantalla | Secciones | Noches |
|---|---|---|---|
| Cliente | `guest/guest_home_page.dart` | Mapa (ficha con «Reservar esta mesa»), Mis reservas, Más | N5: fin de semana de su semana calendario (`NightCatalog.clientWeek`), sin desfase M1 |
| Promotor | La misma pantalla | Igual que el cliente | N7: catálogo operativo y futuro (`NightCatalog.operational`) |
| Administración | `admin/admin_page.dart` | Mapa, Reservas, Entradas y Pedidos (en desarrollo), Más | Operativo y futuro |
| Personal | `staff/staff_page.dart` | Llegadas, Más | Operativo |

No hay pantallas duplicadas para rellenar pestañas.

- **Mapa:** todas las perspectivas usan el mapa v7 compartido (`CrystalMapScaffold`).
- **Cliente y promotor:** leen la consulta pública, sin titulares ajenos. «Mis reservas» pide al almacén la proyección propia (`DemoReservationStore.ownReservations`). El promotor ve solo lo que creó (`createdBy`). El cliente ve, además, lo adjudicado a su cuenta ficticia (`linkedAccountId`) por un promotor, por otro cliente o por una reserva directa del administrador (decisión de interfaz de la demo, 2026-10-11). La adjudicación no cambia quién la creó.
- **Orden de «Mis reservas» (P24):** primero las activas (en proceso, pendiente de pago, reservada u ocupada); las terminadas (canceladas, expiradas, revocadas o liberadas) van en «Historial», plegado al abrir. Cada terminada muestra su motivo (último cambio y hora) y se despliega con sus cambios de estado. Se actualiza en vivo: una reserva que termina pasa sola al historial.
- **Ficha de «Mis reservas»:** tocar una reserva abre una ficha de solo lectura (`guest/my_reservation_detail_page.dart`) con local, noche, mesa, estado, datos de la reserva y cambios de estado. Lee la misma proyección y se actualiza en vivo; no tiene acciones.
- **Personal:** solo localiza reservas confirmadas y registra la llegada (R5) durante la noche en curso (N6), con confirmación. No revoca, no libera ni verifica prepagos.

## Trámite de reserva (`guest/reservation_flow_page.dart`)

- **Mesa normal:**
  - Iniciar: «Reservar esta mesa» llama a `startNormal`, que comprueba la mesa y la bloquea en el almacén, En proceso y sin titular (R14).
  - Datos y envío: el formulario pide al titular (R12, o el perfil del cliente). Tras revisar el resumen, «Enviar» llama a `submitNormal`, que confirma si el trámite sigue activo, sin vencer y con la noche aún abierta (un trámite de las 02:55 enviado a las 03:00 no se confirma, I7).
  - Plazo: se muestra la hora límite. Volver del resumen o pasar a segundo plano no reinician el plazo.
  - Vencer: el trámite queda Expirado y no se puede confirmar.
  - Salir: pide confirmación y llama a `cancelInProcess`, que lo deja Cancelado y libera la mesa (R15).
- **Mesa VIP:**
  - No hay solicitud hasta el envío final (`submitVip`), que vuelve a comprobar la mesa y la deja pendiente de pago, sin caducidad (R16).
  - La VIP directa del administrador no cambia (R7).
- **Vínculo de cuenta:** el promotor, el cliente que reserva para otra persona y la reserva directa del administrador vinculan una cuenta ficticia solo si la cédula coincide exactamente (`DemoIdentities.accountByIdNumber`). Sin coincidencia: «Sin cuenta vinculada». No hay puntos.
- **Privacidad del vínculo:** el cliente y el promotor solo ven «Cuenta encontrada: se vinculará al enviar», sin el nombre ni el teléfono de esa cuenta; el nombre que escribieron sigue visible. La ficha del administrador muestra la cuenta vinculada.
- **Rutas antiguas del libro:** `completeRequest`, `requestNormal` y `requestVip` (siembra y tests del administrador) aplican las mismas comprobaciones que el trámite: titular válido, sin vencer y con la noche abierta.
- **Vista del administrador:** ve cada cambio en su mapa y en sus listas, porque comparte el almacén. Si el trámite no tiene titular, muestra «Titular pendiente (sin enviar)» mientras sigue En proceso y «Sin titular registrado (no se envió)» si se canceló o expiró.

## Límites

- **Datos en memoria:** las sesiones y las reservas son ficticias y se pierden al cerrar la app.
- **Sin pagos:** no hay cobro ni ruta de pago (`NOT DECIDED: proveedor de pagos`).
- **Sin módulos de Entradas, Pedidos ni QR.**
- **Plataformas:** los recorridos de la app se prueban con `TargetPlatformVariant.mobile()` (Android, iOS y Fuchsia); la validación nativa de iOS está pendiente.
