# Seguimiento — cierre de Parte 2 y panel administrador (Parte 3)

> **Nota de vigencia (2026-10-12):** antecedente histórico. Se conserva como registro de la Parte 2 y 3 (rama `feat/admin-reservations-demo`, ya absorbida en `HEAD`) y NO es la orden de trabajo vigente. Para retomar, ver [`continuacion-claude.md`](continuacion-claude.md).

Documento único de checkpoints del encargo del 10 de octubre de 2026. Solo recoge el estado: las decisiones están en `business-rules/`, `decisions/` y `architecture/`. Las horas son de Colombia (UTC−5).

## Terminado

- **A — Parte 2 cerrada.** Commit local `26dbd00` (`feat: add demo reservation rules and shared store`) sobre `e8d8f7b`.
  - **A1:** la siembra omite noches con historial previo. La regresión falló antes (`tableTaken` desde `_seedOnce`, 12:21) y pasa después.
  - **A2:** `refreshAt` se calcula antes que los estados. La regresión falló antes (pendiente con `refreshAt` nulo, desfase de 10 ms) y pasa después.
  - **Verificación:** formato sin cambios, `flutter analyze` sin incidencias, 131/131 tests (12:22).
- **B — Integración.**
  - Un almacén notificador por ejecución y entrada «Administrador (demostración)» con aviso.
  - Las vistas abiertas, también la pública, se actualizan tras cada operación.
  - El administrador lee estados y reservas de una misma consulta.
- **C — Recorridos.**
  - Reserva directa normal y VIP, prepago y rechazo VIP, llegada por horario, revocar, liberar con doble confirmación.
  - Pendientes y reservas/actividad de la noche; detalle por ID.
- **D — Revisión.** Correcciones surgidas:
  - panel lateral estrecho en un móvil pequeño en vertical;
  - desbordes del aviso de carga y de «Elegir mesa» en horizontal;
  - tarjeta del titular en anchos estrechos;
  - estado de «Elegir mesa» con texto al 200 %;
  - repintado del detalle al volver del segundo plano.
- **E.**
  - Verificación: formato, `flutter analyze` y 166/166 tests (12:44).
  - APK debug instalado en el emulador `Medium_Phone_API_36.0` (Android API 36).
  - Recorrido real con capturas.
  - Guía manual escrita (fuera del repositorio).
  - Paquete ZIP e informe (12:58). Se regeneró por la tarde con la documentación actualizada y un informe de Git actual, sin recompilar ni repetir la suite: el código no cambió.
- **H1 (revisión del paquete, 10 de octubre por la tarde).**
  - **Problema:** liberar aceptaba que la reserva pasara de Reservada a Ocupada con el diálogo abierto.
  - **Corrección:** el recorrido fija el estado exacto antes del primer await (I13).
  - **Regresiones:** 2 nuevas, ejecutadas en Android, iOS y Fuchsia. Fallaron antes del arreglo (6/6, 16:07) y pasan después (6/6, 16:08).
  - **Verificación completa:** formato sin cambios, `flutter analyze` sin incidencias y 172/172 tests (16:08).
  - **Evidencia anterior al arreglo:** el APK y las capturas son de las 12:44–12:57. No se recompiló, porque el cambio es solo Dart.
- **F.** Propuesta en `docs/propuesta-siguiente-incremento.md` (`HYPOTHESIS`).

## Pendiente

- La Parte 3 queda sin stage ni commit hasta la revisión.

## Pruebas pendientes de entorno

- Android API 24: no probado.
- iOS nativo: pendiente de macOS/Xcode.
- Llegada en el dispositivo: solo se puede probar a partir de las 8:30 p. m. hora de Colombia; está cubierta por tests con reloj inyectable.

## Próximo paso

- Revisión humana de la rama `feat/admin-reservations-demo` (sin commit).
- Aclaraciones de Juanmi del 10 de octubre por la tarde, registradas:
  - reglas N7, R12 y R13, y decisiones del prototipo del promotor R14–R16;
  - ADR 0003 (Noche contemporánea);
  - plan en dos entregas en `propuesta-siguiente-incremento.md`.
- Referencias SVG y PNG disponibles fuera de Git, en `Rumbaap-referencias/`.
- Configuración de Claude Code (fuera de la Parte 3, sin commit): `.claude/settings.json`, la skill `rumbaap-flutter-ui`, el agente `rumbaap-reviewer` y una entrada en `.gitignore`.
- Para empezar las entregas falta aprobar los commits de la Parte 3 y de la configuración.
