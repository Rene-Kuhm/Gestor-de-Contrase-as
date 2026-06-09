# Vaulta

Vaulta es un gestor de contraseñas offline-first en Flutter orientado a un MVP release-ready: cifrado local real, identidad visual propia y UX honesta sobre lo que está implementado.

## Estado actual

- MVP offline-first para Android, iOS, web, desktop y desarrollo local. El desbloqueo biométrico real del vault está implementado y probado en Android; iOS/macOS/web/desktop conservan el camino de master password hasta tener un binding equivalente.
- App principal renombrada visualmente como `Vaulta`.
- Shell de navegacion con secciones iniciales para vault, access y settings.
- Dashboard del vault con CRUD local cifrado, metricas de seguridad y estados de sync.
- Cifrado local real con ADR-001 v2: Argon2id para KEK, DEK aleatoria por vault, DEK envuelta con AES-256-GCM y payloads AES-256-GCM.
- Migracion de blobs legacy v1 al desbloquear/re-cifrar con master password.
- Supabase sync queda fuera del MVP público por defecto: es opcional/experimental, requiere variables de entorno, sesión autenticada y QA operativo completo antes de prometer confiabilidad.
- Smoke test y tests de seguridad/sync alineados al estado actual.

Nota de seguridad: Vaulta ya cifra datos locales, pero no tuvo auditoría externa. En Android, la biometría desbloquea el vault usando un envelope protegido por Android KeyStore y `BiometricPrompt` con `BIOMETRIC_STRONG`; la master password sigue siendo el camino de recuperación y el requisito para activar o re-enrolar biometría. En iOS, macOS, web y desktop, el vault bloqueado todavía requiere la master password hasta implementar un binding equivalente por plataforma.

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

## Cómo ejecutar en desarrollo

1. Instalar Flutter y validar el entorno con `flutter doctor`.
2. Obtener dependencias con `flutter pub get`.
3. Ejecutar la app con `flutter run`.

## Cómo verificar sin hacer build final

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

Si querés correr en un target específico:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Próximos pasos

- Auditar criptografía y manejo de memoria antes de declarar producción.
- Implementar binding biométrico equivalente en iOS/macOS si se quiere desbloqueo biométrico sin master password fuera de Android.
- Mantener Supabase sync desactivado por defecto para MVP público hasta completar QA operativo: sesión, conflictos, revocación, restore, offline/online y privacidad.
- Expandir tests de UI, dominio y estado.

## Verificación reciente

- `flutter analyze`
- `flutter test`

## Notas para contributors

- No asumir que los datos demo representan seguridad real.
- Evitar mezclar UI con decisiones de criptografía o almacenamiento seguro.
- Mantener la separación entre contratos de dominio y adaptadores concretos.
