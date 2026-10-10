# ADR 0001 — Base de la app Flutter

- **Estado:** `VALIDATED` (decisión explícita del equipo)
- **Fecha:** 2026-10-09

## Contexto

El repositorio solo contenía `CLAUDE.md` y la estructura de `docs/`. Para empezar a implementar funcionalidades hacía falta crear la app Flutter. Crearla obliga a fijar el identificador, las plataformas, las versiones mínimas, la estructura del código y la forma de manejar el estado.

## Decisión

| Tema | Decisión |
|---|---|
| Nombre de la app | Rumbaap |
| Proyecto Dart | `rumbaap` |
| Organización | `com.rumbaap` |
| applicationId (Android) y bundle ID (iOS) | `com.rumbaap.app`, **provisional para desarrollo** |
| Plataformas | Android e iOS (sin web ni escritorio) |
| Mínimo Android | Android 7.0 / API 24 |
| Mínimo iOS | iOS 13.0 |
| Toolchain | Flutter 3.35.2, Dart 3.9 |
| Arquitectura | Modular sencilla: `lib/app` para la composición de la app y `lib/features/<función>` para cada función. Reservas será la primera función. |
| Estado | Estado compartido con `ChangeNotifier` y `ListenableBuilder` del SDK. Se pueden usar `StatefulWidget` y `FutureBuilder` para estado local. |
| Dependencias | Ninguna dependencia externa de ejecución. Como `dev_dependency` solo `flutter_lints`. Se quitó `cupertino_icons`, que añade la plantilla. |

## Consecuencias

- El identificador `com.rumbaap.app` es provisional. Cambiarlo después de publicar en las tiendas no es posible sin crear una app nueva, así que debe confirmarse antes de la primera distribución.
- El SDK mínimo de Android se fija explícitamente (`minSdk = 24` en `android/app/build.gradle.kts`) para que no cambie al actualizar Flutter. iOS 13.0 es el valor que genera Flutter 3.35.2 (`IPHONEOS_DEPLOYMENT_TARGET` y `MinimumOSVersion`).
- Esta decisión no cubre backend, base de datos, autenticación, pagos, analytics, CI/CD, flavors ni acceso a macOS, que siguen `NOT DECIDED` (ver `CLAUDE.md`, sección 4).
