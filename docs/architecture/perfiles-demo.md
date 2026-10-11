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
- **Cliente y promotor:** leen la consulta pública, sin titulares ajenos. «Mis reservas» pide al almacén la proyección propia (`DemoReservationStore.ownReservations`): solo lo que creó esa identidad (`createdBy`). La cuenta vinculada al titular (`linkedAccountId`) es otro dato y no la convierte en creadora (`NOT DECIDED: si el cliente vinculado ve la reserva que hizo un promotor`).
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
- **Vínculo de cuenta:** el promotor vincula una cuenta ficticia solo si la cédula coincide exactamente (`DemoIdentities.accountByIdNumber`). Sin coincidencia: «Sin cuenta vinculada». No hay puntos.
- **Vista del administrador:** ve cada cambio en su mapa y en sus listas, porque comparte el almacén. Si el trámite no tiene titular, muestra «Titular pendiente».

## Límites

- **Datos en memoria:** las sesiones y las reservas son ficticias y se pierden al cerrar la app.
- **Sin pagos:** no hay cobro ni ruta de pago (`NOT DECIDED: proveedor de pagos`).
- **Sin módulos de Entradas, Pedidos ni QR.**
- **Plataformas:** los recorridos de la app se prueban con `TargetPlatformVariant.mobile()` (Android, iOS y Fuchsia); la validación nativa de iOS está pendiente.
