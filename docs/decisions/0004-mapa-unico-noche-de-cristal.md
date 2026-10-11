# ADR 0004 — Mapa único «Noche de cristal» v7 y configuración por local

- **Estado:** `VALIDATED`. Juanmi aprobó P22 el 10/10/2026 a las 19:43 y la ampliación P22.1 a las 19:48 (hora de Colombia). También confirmó los cuatro puntos de arranque de Claude.
- **Sustituye:** la dirección visual del [ADR 0003](0003-direccion-visual-noche-contemporanea.md) («Noche contemporánea» y área VIP «un cuarto menos»).
- **Referencia visual:** maqueta «Noche de cristal» v7, en el artifact `2fVnfMTvegPfpfxWrTZj4v`. Es un diseño con estados ficticios, no una captura de la app.
- **No cambia:** las reglas de [reservas y noches](../business-rules/reservas-y-noches.md), el [ADR 0002](0002-perspectiva-administrador-y-reservas.md) ni la arquitectura del [ADR 0001](0001-base-app-flutter.md).

## Decisión

1. **Un solo mapa.**
   - «Noche de cristal» v7 es la única implementación gráfica del mapa, compartida por todas las perspectivas: hoy, la consulta pública y el administrador.
   - Cada perspectiva aporta sus datos y sus acciones. No se copia el dibujo por perfil.
   - El modelo visual anterior («Mapa y disponibilidad» con el plano de 1000 × 1100) se retira de la app. No hay opción para volver a él. Cualquier cambio futuro del mapa requiere una decisión nueva.
2. **Proporciones VIP de v7.**
   - Tarima de 192 × 68 con baranda dorada y gradas de cuatro escalones.
   - Dos mesas VIP con sofá en U de cuatro cojines.
   - La reducción VIP «un cuarto menos» del ADR 0003 no se aplica.
3. **Configuración por local.**
   - El mapa recibe la configuración del local:
     - identificador y nombre;
     - tema (`VenueTheme`);
     - mesas y zonas;
     - posiciones en el lienzo;
     - condiciones de cada tipo de mesa.
   - Los colores de estado (`StatusColors`) son comunes a todos los locales; el pago VIP pendiente usa el dorado del local.
   - Las 22 mesas, las dos VIP, sus precios, capacidades y geometría son de Sagsa, no reglas universales.
4. **Datos acotados por local.**
   - Un ID de mesa como «M01» solo identifica una mesa dentro de su local.
   - El libro de reservas y el almacén de demostración pertenecen a un único local.
   - Las consultas indican su local y el mapa rechaza las de otro local.
5. **Horario, noches y condiciones.**
   - Se mantienen el horario aprobado (8:30 p. m. – 3:00 a. m.) y las noches de viernes a domingo. El texto «22:00» de la maqueta no se usa.
   - No se muestra «incluye 6 entradas de cortesía»: no hay regla confirmada que lo respalde.

## Consecuencias

- **Pestañas pendientes:** Entradas, Pedidos y Más aparecen en la barra inferior como «En desarrollo», sin acción. No simulan una operación que no existe.
- **Reglas pendientes de parametrizar:** las reglas R1–R8 y el horario siguen definidos en el código como los confirmados para Sagsa. Se parametrizarán por local cuando exista un segundo local con reglas propias (`PENDIENTE`).
- **Sin backend ni multiempresa:** esta decisión no implementa backend multiempresa, hosting, autenticación, un editor de planos ni un catálogo comercial.
- **Skill actualizada:** la skill `rumbaap-flutter-ui` se actualiza para no mantener reglas visuales incompatibles.
