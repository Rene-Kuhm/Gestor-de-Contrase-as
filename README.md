# Vaulta

Vaulta es un gestor de contrasenas en Flutter orientado a construir una base seria para una experiencia de vault moderna, segura y multiplataforma. Hoy el proyecto ya no es el contador demo de Flutter: tiene identidad visual propia, un dashboard inicial del vault, contratos de seguridad y una arquitectura lista para evolucionar sin acoplar UI con implementaciones falsas de criptografia.

## Estado actual

- Base multiplataforma de Flutter lista para Android, iOS, web, desktop y desarrollo local.
- App principal renombrada visualmente como `Vaulta`.
- Shell de navegacion con secciones iniciales para vault, access y settings.
- Dashboard inicial con metricas de seguridad, actividad reciente y datos demo.
- Cifrado local real con ADR-001 v2: Argon2id para KEK, DEK aleatoria por vault, DEK envuelta con AES-256-GCM y payloads AES-256-GCM.
- Migracion de blobs legacy v1 al desbloquear/re-cifrar con master password.
- Pull incremental de sync conectado al vault local cuando hay sesion desbloqueada.
- Smoke test y tests de seguridad/sync alineados al estado actual.

Importante: Vaulta ya cifra datos locales, pero todavia no debe tratarse como solucion auditada de produccion. La biometria funciona como verificacion de UX: por seguridad portable no se persiste ninguna vault key recuperable en base64/JSON; si el vault esta bloqueado, el fallback real es la master password.

## Stack

- Flutter
- Dart `^3.11.3`
- Material 3
- `google_fonts`
- `flutter_secure_storage`
- `local_auth`
- `cryptography`
- `supabase_flutter`
- `flutter_test` + `flutter_lints`

## Estructura relevante

- `lib/main.dart`: entrada minima de la app.
- `lib/app/bootstrap/`: arranque y configuracion principal.
- `lib/app/theme/`: tema visual y tokens base.
- `lib/app/design_system/`: componentes reutilizables.
- `lib/features/`: pantallas y modulos funcionales.
- `lib/core/security/`: master password, sesiones, cifrado AES-GCM v2, almacenamiento seguro y repositorio local cifrado.
- `lib/core/sync/`: push/pull incremental, snapshots remotos, conflictos y bootstrap Supabase opcional.
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

- Auditar criptografia y manejo de memoria antes de declarar produccion.
- Implementar binding biometrico real por plataforma si se quiere unlock sin master password; hasta entonces no guardar claves recuperables.
- Completar resolucion UX de conflictos de sync y mapping estable de tombstones remotos hacia IDs locales cuando el record remoto no sea el ID local.
- Expandir tests de UI, dominio y estado.

## Verificacion reciente

- `flutter analyze`
- `flutter test`

## Notas para contributors

- No asumir que los datos demo representan seguridad real.
- Evitar mezclar UI con decisiones de criptografia o almacenamiento seguro.
- Mantener la separacion entre contratos de dominio y adaptadores concretos.
