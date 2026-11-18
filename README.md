# Rumbaap

Aplicación móvil para gestionar las reservas de mesas, las entradas y la atención de la discoteca **Sagsa**, en Cali.

Proyecto del curso **Ingeniería de Requisitos**, Universidad de San Buenaventura Cali.
Autor: Juan Miguel López Rojas.

## Enlaces

| Qué | Dónde |
|---|---|
| Tablero de historias de usuario | [Rumbaap · Historias de usuario](https://github.com/users/DracoJM/projects/1) |
| Integración del prototipo, con su revisión de código | [Pull request #58](https://github.com/DracoJM/Rumbaap/pull/58) |
| Documentación técnica y de producto | [docs/](docs/README.md) |
| Historias de usuario | [Issues HU-01 a HU-52](https://github.com/DracoJM/Rumbaap/issues?q=is%3Aissue+HU-) |

## Estado

Prototipo funcional del front-end en Flutter, con datos de demostración, sin servidor ni pagos reales. Cubre la operación de una noche por perfil: cliente, promotor, administrador, mesero, puerta, taquilla y barra.

Las decisiones de servidor, base de datos, autenticación y proveedor de pagos siguen abiertas.

## Cómo ejecutarlo

Requiere Flutter 3.35 o superior y un emulador o teléfono Android 7.0 o superior.

```bash
flutter pub get
flutter run
```

Pruebas y análisis:

```bash
flutter analyze
flutter test
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/` | Código de la aplicación, organizado por módulos en `lib/features/` |
| `test/` | Pruebas de dominio y de pantallas |
| `docs/` | Reglas de negocio, decisiones (ADR), arquitectura, planes de prueba y propuestas |
| `android/`, `ios/` | Proyectos nativos |
