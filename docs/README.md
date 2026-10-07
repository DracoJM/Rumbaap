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
