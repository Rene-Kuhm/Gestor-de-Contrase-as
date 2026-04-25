# Android release signing

Vaulta release builds must not use the debug keystore.

## Option A: `android/key.properties`

Create this file locally. Do not commit it.

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

## Option B: environment variables

Set these in CI or your shell:

- `VAULTA_UPLOAD_STORE_FILE`
- `VAULTA_UPLOAD_STORE_PASSWORD`
- `VAULTA_UPLOAD_KEY_ALIAS`
- `VAULTA_UPLOAD_KEY_PASSWORD`

If none are present, Gradle leaves `release` unsigned instead of falling back to debug signing. That is intentional.
