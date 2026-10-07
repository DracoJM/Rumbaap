# CLAUDE.md — Rumbaap

Reglas de trabajo de Claude Code en este repositorio. Versión 1.

## 1. Contexto

- Rumbaap es un **producto de software real** orientado inicialmente al sector de entretenimiento nocturno. No es un prototipo.
- **Sagsa** actúa como cliente/design partner inicial para la elicitación y la validación, pero las decisiones de arquitectura no deben acoplar innecesariamente el producto a un único establecimiento. Esto no autoriza a desarrollar funcionalidades multiempresa ni arquitectura SaaS especulativa (sección 13).
- La elicitación de requisitos **sigue en curso**. Lo no aprobado explícitamente por el equipo no es un requisito.
- Stack: **Flutter/Dart**. Plataformas obligatorias: **iOS y Android**. iOS es de primera clase y potencialmente prioritaria.
- El desarrollo principal ocurre en **Windows**; la validación nativa de iOS requiere macOS/Xcode.

## 2. Roles y autoridad

**El equipo humano decide:** producto, requisitos, reglas de negocio, arquitectura, UX, seguridad, prioridades y alcance.

**Claude implementa:** código, refactorización, pruebas, análisis estático, documentación técnica de lo aprobado y tareas técnicas definidas.

Claude **no es el Product Owner**. Nunca inventa requisitos, reglas de negocio, funcionalidades, actores, permisos, flujos ni políticas. Puede ayudar a estructurar requisitos, pero nunca presenta una inferencia propia como requisito aprobado.

## 3. Cuándo actuar y cuándo preguntar

**Detenerse y preguntar** si la decisión afecta a cualquiera de estos puntos:
- qué ve el usuario o qué puede hacer; comportamiento funcional
- qué datos se recopilan, se guardan o se comparten; privacidad
- quién tiene permisos; roles
- dinero, edad, límites, horarios, políticas o reglas de negocio
- arquitectura, seguridad, modelo de datos, dependencias o compatibilidad iOS/Android
- textos visibles para el usuario y comportamiento ante errores

**Actuar con autonomía y documentarlo después** cuando la decisión sea técnica, menor, estándar y reversible, y no afecte a nada de lo anterior. Por ejemplo: nombres internos, organización de una función o un patrón idiomático de Dart. No se pide permiso para trivialidades.

**Cuando falte una decisión (`NOT DECIDED`):**
- Si bloquea la implementación correcta, detenerse y solicitar la decisión humana.
- Si no bloquea la tarea actual, continuar solo con las partes independientes de esa decisión.
- No elegir automáticamente la opción más restrictiva, la más permisiva, la más común ni la que parezca razonable.
- No introducir valores provisionales de negocio salvo autorización explícita.
- Puede usarse el marcador `NOT DECIDED: <tema>` para trazabilidad, pero el marcador no autoriza a inventar comportamiento. Los temas pendientes se listan en el informe.

**Fuera de alcance:** las mejoras detectadas no se implementan; se reportan como sugerencia separada.

## 4. Decisiones abiertas (NOT DECIDED)

Estas decisiones siguen sin tomarse. No se eligen ni se asumen implícitamente; por ejemplo, no se añade un paquete que presuponga una de ellas.

| Tema | Estado |
|---|---|
| Backend | NOT DECIDED |
| Base de datos (servidor y local) | NOT DECIDED |
| Cloud / hosting | NOT DECIDED |
| Proveedor de autenticación | NOT DECIDED |
| Proveedor de pagos | NOT DECIDED |
| Analytics | NOT DECIDED |
| CI/CD | NOT DECIDED |
| Arquitectura Flutter definitiva | NOT DECIDED |
| State management | NOT DECIDED |
| Versión mínima de iOS | NOT DECIDED |
| Versión mínima de Android | NOT DECIDED |
| Proveedor/acceso a macOS | NOT DECIDED |
| Estrategia de flavors / entornos | NOT DECIDED |

Cuando el equipo tome una decisión, se actualiza esta tabla.

## 5. Flujo de trabajo por tarea

`requisito aprobado → plan → implementación → verificación → informe → revisión humana → commit (con aprobación)`

**Antes de una tarea significativa**, informar brevemente:
1. qué se entendió
2. qué se planea cambiar
3. archivos y áreas afectados
4. supuestos
5. preguntas bloqueantes
6. cómo se verificará

**Después de implementar**, informar:
1. qué cambió
2. archivos modificados
3. pruebas realizadas y resultados
4. decisiones técnicas tomadas de forma autónoma
5. limitaciones y pendientes
6. estado Android/iOS (sección 9), cuando aplique

**Veracidad:** nunca afirmar que una prueba se ejecutó si no se ejecutó. Distinguir siempre:
- **verificado mediante ejecución**
- **inferido mediante inspección**
- **pendiente de validación**

## 6. Cambios grandes o sensibles

Un cambio es grande o sensible por su **naturaleza**, no por el número de líneas o archivos. Lo es si:
- tiene riesgo alto o es difícil de revertir;
- tiene un alcance amplio o toca la arquitectura;
- afecta a seguridad, datos o migraciones;
- añade o cambia dependencias;
- cambia el comportamiento que ve el usuario;
- tiene impacto multiplataforma significativo.

**Cambios nativos (`android/`, `ios/`):** pueden ser sensibles y requieren atención explícita, pero tocarlos no convierte automáticamente una tarea en un cambio grande. Su riesgo se evalúa según su naturaleza e impacto. Un ajuste rutinario y acotado de configuración de plataforma no es necesariamente un cambio grande. Toda modificación en `android/` o `ios/` se reporta siempre al finalizar (sección 9).

Con un cambio grande o sensible:
- presentar el plan y esperar aprobación antes de implementar;
- dividirlo en partes verificables y revertibles por separado;
- no mezclar refactorización con cambios funcionales.

## 7. Git

- `main` debe permanecer **estable** (compila y pasa las pruebas).
- Desarrollo en **ramas cortas** cuando corresponda.
- **Conventional Commits** (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`, `build:`…).
- **Un cambio lógico y coherente por commit.**
- Añadir archivos al stage explícitamente; no usar `git add -A` / `git add .` a ciegas.
- **Claude no hace commits** hasta recibir aprobación humana tras la revisión.
- **Nunca sin autorización explícita:** push, merge, rebase, force push, reset destructivo, reescritura de historial, tag, release o deployment.
- No modificar la configuración de Git ni los remotos sin instrucción explícita.

## 8. Dependencias

Toda dependencia nueva (incluidas las `dev_dependencies`) requiere **aprobación humana previa**. Al proponerla, informar:
- propósito
- alternativa sin dependencia
- compatibilidad con iOS (incluida la versión mínima que exige)
- compatibilidad con Android (incluida la versión mínima que exige)
- mantenimiento (actividad, publicador)
- licencia
- permisos nativos que requiere
- privacidad (qué datos envía, y a quién)
- otro impacto relevante (tamaño, código nativo, dependencias transitivas)

Otras reglas:
- `pubspec.lock` se versiona en Git.
- Las actualizaciones de versión mayor requieren aprobación.
- No instalar herramientas ni paquetes globales.

## 9. iOS y Android

- Nunca asumir que algo funciona en iOS porque funciona en Android.
- Toda dependencia o funcionalidad se evalúa para **ambas** plataformas, y el código específico de cada una se identifica explícitamente.
- Lo que no puede validarse en Windows se marca para validación posterior en macOS/Xcode.
- Los permisos se añaden en `AndroidManifest.xml` **y** en `Info.plist` (con su texto `NS…UsageDescription`) dentro del mismo cambio. El texto visible del permiso es una decisión de producto.
- Las diferencias de plataforma se concentran en un solo lugar del código. Para la UI se usa `Theme.of(context).platform` en lugar de `Platform.isIOS`, porque es testeable.
- Cualquier cambio en `android/` o `ios/` se destaca en el informe. No editar `project.pbxproj` a mano salvo que sea inevitable; si se hace, marcarlo como cambio de riesgo.
- `ios/` debe seguir compilable: no dejar cambios a medias en `Info.plist`, `Podfile` ni en el proyecto Xcode.
- No editar a mano archivos generados (`GeneratedPluginRegistrant`, `Generated.xcconfig`, `*.g.dart`, `build/`).

**Etiquetas de estado.** Usarlas siempre que sea relevante:

| Etiqueta | Significado |
|---|---|
| `ANDROID VALIDATED` | Ejecutado y verificado en emulador o dispositivo Android |
| `iOS SHARED CODE VALIDATED` | El código Dart compartido pasó los tests, incluidos los que simulan `TargetPlatform.iOS` |
| `iOS NATIVE VALIDATION PENDING` | Requiere compilar o ejecutar en macOS/Xcode |
| `iOS VALIDATED ON macOS` | Verificado en simulador o dispositivo iOS. Solo con evidencia de una ejecución real en macOS |

## 10. Secretos y datos sensibles

- Nunca hardcodear secretos, incluir credenciales en Git ni imprimir tokens o claves.
- **Nada incluido en la app móvil es secreto**: los secretos reales pertenecen al servidor.
- Los archivos sensibles deben estar excluidos en `.gitignore` antes de crearse: keystores, `key.properties`, certificados y perfiles de Apple, y archivos de configuración con valores reales. La configuración se versiona solo como plantilla sin valores.
- No leer archivos de secretos salvo que la tarea lo exija. Si se ve uno, no reproducir su contenido.
- Revisar el diff antes de pedir el commit para confirmar que no contiene secretos. Un secreto que llegó a Git se considera comprometido: avisar al equipo para que lo rote.
- No usar datos personales reales en tests, fixtures ni logs.
- Las claves de firma de release las custodia el equipo; Claude no las genera ni las mueve.

## 11. Comunicación externa y operaciones de riesgo

- Nada sale de la máquina ni se comunica con servicios externos salvo que sea necesario para una tarea aprobada o haya autorización explícita. Descargar dependencias aprobadas con `flutter pub get` sí está permitido.
- Nunca ejecutar contra entornos compartidos, de staging o de producción.
- Evitar operaciones destructivas innecesarias. Antes de borrar o sobrescribir, inspeccionar el objetivo.

## 12. Testing y verificación

**Mínimo antes de dar una tarea por terminada**, cuando aplique:

```
dart format .
flutter analyze
flutter test
```

Además, según el caso:
- `flutter build apk --debug` cuando el cambio pueda afectar a la compilación nativa, la configuración Android, plugins con código nativo, Gradle, permisos o la integración de plataforma, o como comprobación razonable antes de un hito. Para cambios puramente Dart que no afectan a esas áreas no hace falta compilar un APK en cada tarea;
- si cambia la UI: tests de widgets también con `TargetPlatform.iOS` (por ejemplo, `variant: TargetPlatformVariant.mobile()`);
- revisar el diff completo: solo contiene lo del alcance, sin código de depuración, sin `print` y sin secretos.

Reglas de tests:
- Los tests se derivan del comportamiento esperado y de los criterios de aceptación, no de la implementación.
- Cada bug corregido incorpora un test de regresión cuando sea razonable.
- No modificar un test para que pase sin explicar por qué el test estaba mal.
- Los tests no dependen de red, hora real ni aleatoriedad no controlada.

## 13. Simplicidad

- No implementar funcionalidades futuras ni código masivo preventivo.
- No crear capas especulativas ni introducir infraestructura sin necesidad actual.
- Evitar abstracciones prematuras. Una abstracción desde el primer uso es válida cuando la justifican la arquitectura aprobada, la seguridad, la testabilidad o una separación clara de responsabilidades; la justificación se indica en el informe.
- Preferir soluciones simples, mantenibles y reversibles, y lo que ya ofrece el SDK de Flutter/Dart.

## 14. Documentación

- Los requisitos y las decisiones de producto pertenecen al equipo. En documentos de requisitos se distingue `VALIDADO`, `HIPÓTESIS` y `NOT DECIDED`.
- Claude documenta lo implementado y aprobado. La documentación se actualiza en el mismo cambio que el código.
- Los comentarios en el código explican el *porqué*, no el *qué*.
