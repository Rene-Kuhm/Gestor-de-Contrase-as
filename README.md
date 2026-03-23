# Vaulta

Vaulta es un gestor de contrasenas en Flutter orientado a construir una base seria para una experiencia de vault moderna, segura y multiplataforma. Hoy el proyecto ya no es el contador demo de Flutter: tiene identidad visual propia, un dashboard inicial del vault, contratos de seguridad y una arquitectura lista para evolucionar sin acoplar UI con implementaciones falsas de criptografia.

## Estado actual

- Base multiplataforma de Flutter lista para Android, iOS, web, desktop y desarrollo local.
- App principal renombrada visualmente como `Vaulta`.
- Shell de navegacion con secciones iniciales para vault, access y settings.
- Dashboard inicial con metricas de seguridad, actividad reciente y datos demo.
- Contratos definidos para almacenamiento seguro, cifrado del vault y repositorio.
- Smoke test alineado al nuevo shell.

Importante: la app todavia usa un repositorio demo. No implementa cifrado real, biometria ni persistencia segura productiva. Es una fundacion de producto, no una solucion final de seguridad.

## Stack

- Flutter
- Dart `^3.11.3`
- Material 3
- `google_fonts`
- `flutter_test` + `flutter_lints`

## Estructura relevante

- `lib/main.dart`: entrada minima de la app.
- `lib/app/bootstrap/`: arranque y configuracion principal.
- `lib/app/theme/`: tema visual y tokens base.
- `lib/app/design_system/`: componentes reutilizables.
- `lib/features/`: pantallas y modulos funcionales.
- `lib/core/security/`: contratos de seguridad y repositorio demo.
- `test/widget_test.dart`: smoke test principal actual.

## Como ejecutar en desarrollo

1. Instalar Flutter y validar el entorno con `flutter doctor`.
2. Obtener dependencias con `flutter pub get`.
3. Ejecutar la app con `flutter run`.

## Como verificar sin hacer build final

Usa estas validaciones locales durante desarrollo:

```bash
flutter analyze
flutter test
```

Si queres correr en un target especifico:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Proximos pasos

- Integrar almacenamiento seguro real con Keychain/Keystore mediante una abstraccion concreta.
- Definir flujo de onboarding, master password y desbloqueo biometrico.
- Reemplazar `DemoVaultRepository` por persistencia real del vault.
- Incorporar cifrado auditado y estrategia de manejo de claves.
- Diseñar sync segura antes de conectar cualquier backend.
- Expandir tests de UI, dominio y estado.

## Verificacion reciente

- `flutter analyze`
- `flutter test`

## Notas para contributors

- No asumir que los datos demo representan seguridad real.
- Evitar mezclar UI con decisiones de criptografia o almacenamiento seguro.
- Mantener la separacion entre contratos de dominio y adaptadores concretos.
