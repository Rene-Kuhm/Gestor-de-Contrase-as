# Vaulta

Vaulta es un gestor de contrasenas offline-first en Flutter orientado a un MVP release-ready: cifrado local real, identidad visual propia y UX honesta sobre lo que esta implementado.

## Estado actual

- MVP offline-first para Android, iOS, web, desktop y desarrollo local.
- App principal renombrada visualmente como `Vaulta`.
- Shell de navegacion con secciones iniciales para vault, access y settings.
- Dashboard del vault con CRUD local cifrado, metricas de seguridad y estados de sync.
- Cifrado local real con ADR-001 v2: Argon2id para KEK, DEK aleatoria por vault, DEK envuelta con AES-256-GCM y payloads AES-256-GCM.
- Migracion de blobs legacy v1 al desbloquear/re-cifrar con master password.
- Supabase sync es opcional/experimental: requiere variables de entorno, sesion autenticada y todavia necesita validacion operativa antes de prometer confiabilidad.
- Smoke test y tests de seguridad/sync alineados al estado actual.

Nota de seguridad: Vaulta ya cifra datos locales, pero no tuvo auditoria externa. La biometria funciona como verificacion local/UX: por seguridad portable no se persiste ninguna vault key recuperable en base64/JSON; si el vault esta bloqueado, el desbloqueo real requiere la master password.

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

## Release Android

La variante release ya no usa debug signing. Para firmar, configura secretos fuera del repo con `android/key.properties` o variables `VAULTA_UPLOAD_*`. Ver `docs/android-release-signing.md`.

Para checklist de Google Play / App Store y plantilla de privacidad, ver:

- `docs/store-release-checklist.md`
- `docs/privacy-policy-template.md`

Si queres correr en un target especifico:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Proximos pasos

- Auditar criptografia y manejo de memoria antes de declarar produccion.
- Implementar binding biometrico real por plataforma si se quiere unlock sin master password; hasta entonces no guardar claves recuperables.
- Completar hardening de Supabase sync antes de declararlo confiable/sync-ready por defecto.
- Expandir tests de UI, dominio y estado.

## Verificacion reciente

- `flutter analyze`
- `flutter test`

## Notas para contributors

- No asumir que los datos demo representan seguridad real.
- Evitar mezclar UI con decisiones de criptografia o almacenamiento seguro.
- Mantener la separacion entre contratos de dominio y adaptadores concretos.
