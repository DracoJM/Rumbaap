# Documentación de Rumbaap

Este directorio contiene la documentación de producto y técnica de Rumbaap. Las reglas de trabajo de Claude Code están en [`CLAUDE.md`](../CLAUDE.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| [`product/`](product/) | Visión, alcance, objetivos, actores y contexto del producto, una vez aprobados. |
| [`requirements/`](requirements/) | Requisitos funcionales, no funcionales y criterios de aceptación aprobados. |
| [`business-rules/`](business-rules/) | Reglas de negocio validadas y trazables. |
| [`architecture/`](architecture/) | Arquitectura técnica aprobada y documentación técnica de alto nivel. |
| [`decisions/`](decisions/) | Decisiones técnicas o de producto formalmente aprobadas que necesitan trazabilidad, incluidos ADR cuando corresponda. |
| [`elicitation/`](elicitation/) | Evidencia y resultados estructurados de entrevistas, grupos focales, observaciones y otras actividades de elicitación. |

## Estados de la información

Todo contenido debe indicar claramente su estado:

| Estado | Significado |
|---|---|
| `VALIDATED` | Información confirmada mediante evidencia de elicitación suficiente o mediante una decisión explícita del equipo. |
| `HYPOTHESIS` | Suposición, propuesta, interpretación o posible solución que todavía requiere validación. |
| `NOT DECIDED` | Tema identificado sobre el que todavía no existe una decisión aprobada. |

Los identificadores de estado se escriben siempre en inglés, aunque el texto esté en español.

`VALIDATED` no equivale a requisito. Una información validada puede ser un hecho del proceso actual, un dolor, una necesidad, una regla de negocio, una restricción u otra evidencia confirmada. Solo se convierte en requisito cuando el equipo la analiza y la aprueba como tal.

## Reglas

1. Una `HYPOTHESIS` nunca se convierte automáticamente en requisito.
2. Una observación o solicitud de un stakeholder tampoco se convierte automáticamente en requisito aprobado.
3. `elicitation/` registra evidencia. `requirements/` y `business-rules/` contienen conocimiento ya analizado y aprobado.
4. Cuando sea razonable, cada requisito y regla de negocio debe poder rastrearse hasta la evidencia de elicitación que lo originó.
5. Claude puede organizar y analizar información, pero la aprobación de requisitos, reglas de negocio y decisiones corresponde al equipo humano.
6. No se duplica información entre documentos sin necesidad. Si existe una fuente canónica, se referencia en lugar de copiarla.

## Índice por tema

Para retomar: [`continuacion-claude.md`](continuacion-claude.md) y `git status`; después, solo el tema afectado. El detalle de artefactos, hashes, fuentes externas y estados está en [`continuidad/fuentes-y-evidencia.md`](continuidad/fuentes-y-evidencia.md).

| Tema | Archivo | Evidencia que consultar |
|---|---|---|
| Noches, reservas, mesas normal y VIP, mapa de consulta | [`business-rules/reservas-y-noches.md`](business-rules/reservas-y-noches.md), [`architecture/reservations-venue-map.md`](architecture/reservations-venue-map.md) | Entrevistas E1 P10 y E2 P8–P9; ADR 0002 |
| Prepago VIP, Barra, cliente sin cuenta | [`business-rules/pedidos-barra.md`](business-rules/pedidos-barra.md) | `test/features/bar/` |
| Champaña y cortesías VIP | [`business-rules/beneficios-vip.md`](business-rules/beneficios-vip.md) | `test/features/benefits/`, `vip_champagne*_test`; QA nativa de `0b2324b` (solo bloqueo fuera de horario) |
| Cumpleaños | [`business-rules/cumpleanos.md`](business-rules/cumpleanos.md) | E1 P6, P7 y E2 P13; QA nativa de `0b2324b` |
| Entradas, manillas, Promotor, credencial y QR | [`business-rules/entradas.md`](business-rules/entradas.md), [`proposals/qr-escaneable-y-camara.md`](proposals/qr-escaneable-y-camara.md) | `test/features/tickets/` |
| Perfiles, panel de administración | [`architecture/perfiles-demo.md`](architecture/perfiles-demo.md), [`architecture/admin-reservations-demo.md`](architecture/admin-reservations-demo.md), [`architecture/panel-admin.md`](architecture/panel-admin.md) | `test/features/reservations/`, `test/features/dashboard/` |
| Mapa y sistema visual | [`architecture/mapa-noche-de-cristal.md`](architecture/mapa-noche-de-cristal.md), [ADR 0004](decisions/0004-mapa-unico-noche-de-cristal.md), [ADR 0005](decisions/0005-sistema-visual-compartido.md) | Capturas de render de widgets (no son QA Android) |
| Base técnica y decisiones | [ADR 0001](decisions/0001-base-app-flutter.md), [ADR 0002](decisions/0002-perspectiva-administrador-y-reservas.md); el [ADR 0003](decisions/0003-direccion-visual-noche-contemporanea.md) está sustituido por el 0004 | — |
| Antecedentes históricos (no órdenes vigentes) | [`seguimiento-parte3.md`](seguimiento-parte3.md), [`propuesta-siguiente-incremento.md`](propuesta-siguiente-incremento.md) | — |
| Fuentes externas, hashes, estados, decisiones abiertas | [`continuidad/fuentes-y-evidencia.md`](continuidad/fuentes-y-evidencia.md) | `entrega.txt` de cada carpeta de entrega |
