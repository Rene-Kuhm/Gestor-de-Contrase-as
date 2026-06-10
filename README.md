# Vaulta

**Gestor de contrasenas cifrado, offline-first y multiplataforma.**

Vaulta es una aplicacion desarrollada por [TecnoDespegue](https://www.tecnodespegue.com/) para proteger credenciales sensibles con una experiencia moderna, rapida y preparada para Android. El proyecto combina Flutter, Material 3, cifrado local real, desbloqueo biometrico en Android y un canal de actualizaciones firmado desde GitHub Releases.

[Descargar APK](https://github.com/Rene-Kuhm/Gestor-de-Contrase-as/releases/download/dev-latest/vaulta.apk) · [Ver release](https://github.com/Rene-Kuhm/Gestor-de-Contrase-as/releases/tag/dev-latest) · [TecnoDespegue](https://www.tecnodespegue.com/)

## Vision

Vaulta nace como una solucion de seguridad personal construida con el enfoque de TecnoDespegue: codigo real, arquitectura limpia, automatizacion confiable y decisiones tecnicas transparentes.

El objetivo es ofrecer un vault local para guardar, buscar y gestionar credenciales sin depender de una conexion permanente, manteniendo una base preparada para evolucionar hacia sincronizacion segura, auditorias de seguridad y distribucion publica.

## Funcionalidades principales

- Vault offline-first con persistencia local cifrada.
- Cifrado AES-256-GCM para payloads del vault.
- Derivacion de claves con Argon2id.
- DEK aleatoria por vault y envelope protegido.
- Desbloqueo con master password.
- Desbloqueo biometrico real en Android mediante Android KeyStore y `BiometricPrompt`.
- CRUD de credenciales con busqueda interna.
- Dashboard con metricas de seguridad del vault.
- Estados de carga, error, vacio y resultados.
- Bloqueo automatico por inactividad o cambio de estado de la app.
- Soporte inicial para autofill en Android.
- Canal de actualizaciones Android desde GitHub Releases.
- Publicacion automatica de APK firmada como `vaulta.apk`.

## Estado del producto

Vaulta esta en etapa MVP release-ready para Android. La app ya cuenta con cifrado local, biometria Android, actualizaciones firmadas, iconos Android personalizados y auditoria funcional reciente del buscador interno y las pantallas principales.

El desbloqueo biometrico completo esta implementado para Android. En iOS, macOS, web y desktop se conserva el camino de master password hasta implementar bindings equivalentes por plataforma.

> Nota de seguridad: Vaulta cifra datos locales, pero todavia no cuenta con auditoria criptografica externa. No se debe presentar como producto de seguridad certificado hasta completar una revision independiente.

## Stack tecnico

- Flutter
- Dart `^3.11.3`
- Material 3
- `flutter_secure_storage`
- `local_auth`
- `cryptography`
- `supabase_flutter`
- Android KeyStore
- GitHub Actions
- GitHub Releases

## Arquitectura

```text
lib/
  app/
    bootstrap/        Arranque y configuracion principal
    design_system/   Componentes visuales reutilizables
    theme/           Tokens, colores y tema Material
  core/
    security/        Master password, cifrado, biometria y storage seguro
    sync/            Contratos y servicios de sincronizacion opcional
    update/          Verificacion de actualizaciones
  features/
    home/            Shell principal y navegacion
    security/        Gate de bloqueo y desbloqueo
    vault/           Dashboard, busqueda, detalle y editor de credenciales
    settings/        Configuracion, biometria, sync y actualizaciones
    access/          Integracion de autofill Android
```

## Seguridad

Vaulta implementa una postura de seguridad local basada en:

- Master password como factor principal de recuperacion.
- Argon2id para derivacion de clave.
- AES-256-GCM para cifrado autenticado.
- Clave DEK independiente del password del usuario.
- Envelope protegido para desbloqueo biometrico en Android.
- Bloqueo automatico al salir de primer plano o por inactividad.
- Manejo explicito de estados de error y sesiones revocadas.

La sincronizacion remota con Supabase existe como base tecnica opcional/experimental y no esta habilitada como promesa publica por defecto.

## Instalacion Android

Descargar el APK firmado desde el release actual:

[vaulta.apk](https://github.com/Rene-Kuhm/Gestor-de-Contrase-as/releases/download/dev-latest/vaulta.apk)

Instalacion manual por ADB:

```bash
adb install -r vaulta.apk
```

Tambien se puede actualizar desde la app:

```text
Ajustes > Buscar actualizaciones
```

## Desarrollo local

Requisitos:

- Flutter estable
- Dart compatible con el SDK del proyecto
- Android Studio o toolchain Android para builds Android

Comandos principales:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build Android release:

```bash
flutter build apk --release
```

La firma Android release requiere secretos fuera del repositorio. Ver [docs/android-release-signing.md](docs/android-release-signing.md).

## Validacion

Validaciones esperadas antes de publicar cambios:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

El pipeline de GitHub Actions compila, analiza, firma y publica automaticamente el APK en `dev-latest` con el nombre profesional `vaulta.apk`.

## Documentacion relacionada

- [Firma y release Android](docs/android-release-signing.md)
- [Checklist de publicacion en stores](docs/store-release-checklist.md)
- [Plantilla de politica de privacidad](docs/privacy-policy-template.md)

## TecnoDespegue

TecnoDespegue desarrolla software fullstack, apps moviles multiplataforma y automatizaciones con IA para negocios que necesitan sistemas reales, escalables y mantenibles.

- Web: [tecnodespegue.com](https://www.tecnodespegue.com/)
- Especialidades: Flutter, Dart, Next.js, TypeScript, Python, automatizaciones con IA, APIs, integraciones y optimizacion de procesos.
- Enfoque: foco tecnico, codigo limpio, comunicacion transparente y entregas medibles.

## Licencia

Proyecto privado/publico de portafolio tecnico de TecnoDespegue. Definir una licencia formal antes de aceptar contribuciones externas o distribuir el codigo como open source.
