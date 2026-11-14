# ADR 0003 — Dirección visual «Noche contemporánea» del mapa

- **Estado:** `SUPERSEDED` por el [ADR 0004](0004-mapa-unico-noche-de-cristal.md) (10/10/2026). Antes `VALIDATED` (elección explícita de Juanmi, D15). Se conserva como historial; su acabado y la reducción VIP ya no se aplican.
- **Fecha:** 2026-10-10
- **Referencia:** `Rumbaap_noche_contemporanea.svg` y su PNG, junto con el brief visual de Flutter y Figma (revisión 2). Son un diseño, no capturas de la app. Los estados que muestran son ficticios. No están en el repositorio.

## Contexto

El mapa de mesas (Parte 1) y la vista del administrador (Parte 3) comparten el mismo dibujo nativo. El equipo comparó dos alternativas de acabado y eligió una.

## Decisión

- **Acabado:**
  - grafito frío, líneas limpias y tapicería azul gris;
  - metal sutil y luces azul/violeta;
  - sombras y luz con moderación.
- **Se descarta Club premium.** No se mezclan las dos alternativas.
- **Lo que se conserva:**
  - Flutter/Dart con dibujo nativo; el mapa no se convierte en una imagen estática;
  - la geometría y la disposición de las 22 mesas, la barra, el DJ, las escaleras y el acceso;
  - las coordenadas de las mesas normales;
  - la animación de luces del DJ, la selección y los estados;
  - la pausa fuera de pantalla o en segundo plano, y la reducción de movimiento (M4).
- **Estados:** Disponible, En proceso, Pago VIP, Reservada, Ocupada y Sin información conservan su significado, con color, icono y etiqueta. Nunca dependen solo del color.
- **Área VIP «un cuarto menos»:** es la única excepción visual al contorno anterior.
  - El mobiliario VIP se dibuja a escala 0,75 alrededor del mismo centro: 138 unidades dibujadas en lugar de 184. La caja lógica y táctil sigue en 184, con los mismos IDs.
  - La tarima conserva su ancho (640) y su borde norte (y = 20). Su altura visible pasa de 216 a 162 (borde inferior en y = 182), lo que reduce su superficie dibujada exactamente un 25 %.
  - Los centros VIP siguen en (330, 112) y (670, 112).
  - El 0,75 se refiere a las dimensiones del mueble, cuya superficie baja más de un 25 %. El 25 % exacto se refiere a la superficie de la tarima. No son la misma magnitud.
- **Accesibilidad:** las etiquetas, los iconos, las áreas táctiles y la semántica siguen legibles y operables. No se escala la pantalla entera ni se reducen las mesas normales.

## Lo que esta decisión no cambia

- Es una representación visual. No cambia el espacio físico ni el aforo del local.
- No cambia capacidades ni precios: cada VIP sigue siendo de 20 personas y 2.000.000 COP de prepago.
- No cambia ninguna regla de reserva.
- No autoriza unir las dos VIP ni rediseñar el plano.
- No introduce dependencias ni cambia el SDK.

## Consecuencias

- La aplicará la entrega 1 de la [propuesta](../propuesta-siguiente-incremento.md).
- Para implementarla hace falta tener a mano el SVG o el PNG de referencia.
- Las pruebas de esa entrega comprueban, entre otras cosas, que:
  - las 22 mesas conservan sus IDs, centros y cajas táctiles;
  - la escala VIP y la tarima tienen las medidas de esta decisión;
  - no hay desbordes en un móvil pequeño, en horizontal ni con texto al 200 %.
