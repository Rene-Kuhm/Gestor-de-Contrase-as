# ADR-001: Derivacion de claves y formato de blob cifrado v2

- Estado: Aprobado
- Fecha: 2026-03-23

## Contexto

La app necesita un esquema de cifrado estable para secretos locales y sincronizados, con parametros versionables para migraciones futuras y validacion criptografica fuerte.

## Decision

Se congela el esquema criptografico v2 con estas reglas:

1. Derivacion de clave maestra (KEK): Argon2id sobre la master password, con salt aleatoria de 16 bytes por usuario.
2. Parametros iniciales Argon2id v2: `memory=64 MiB`, `iterations=3`, `parallelism=1`, `output=32 bytes`.
3. Clave de datos (DEK): aleatoria de 32 bytes por vault de usuario.
4. Envoltorio de DEK: la DEK se cifra con la KEK usando AES-256-GCM.
5. Cifrado de entradas: cada item se cifra con la DEK usando AES-256-GCM y nonce unica de 12 bytes por registro/version.
6. Formato blob cifrado v2: contenedor JSON con version explicita y metadatos de KDF/nonce/tag para permitir migraciones.

Ejemplo de forma del blob v2 (referencial):

```json
{
  "v": 2,
  "kdf": {
    "name": "argon2id",
    "salt_b64": "...",
    "memory_kib": 65536,
    "iterations": 3,
    "parallelism": 1,
    "dk_len": 32
  },
  "dek_wrap": {
    "alg": "AES-256-GCM",
    "nonce_b64": "...",
    "ciphertext_b64": "...",
    "tag_b64": "..."
  },
  "payload": {
    "alg": "AES-256-GCM",
    "nonce_b64": "...",
    "ciphertext_b64": "...",
    "tag_b64": "..."
  }
}
```

## Alternativas consideradas

- PBKDF2-HMAC-SHA256: mayor compatibilidad, menor resistencia GPU frente a Argon2id.
- Scrypt: valida, pero Argon2id tiene adopcion mas clara en recomendaciones modernas para password hashing.
- ChaCha20-Poly1305 para todo: mejor en dispositivos sin AES acceleration, pero se prioriza estandarizacion AES-GCM para este batch.

## Consecuencias / tradeoffs

- Seguridad: mejora frente a KDFs legacy, con costo computacional superior en login/desbloqueo.
- UX: posible latencia perceptible al derivar KEK en dispositivos gama baja.
- Operacion: formato v2 versionado facilita migraciones sin romper blobs existentes.
- Complejidad: requiere manejo estricto de nonces unicas y metadatos criptograficos.

## Criterios de aceptacion verificables

- Todo blob nuevo persiste `v=2` y bloque `kdf` completo.
- No se reutiliza nonce para una misma clave (test de colision en lote de muestras).
- La derivacion con password incorrecta nunca produce descifrado valido.
- Se puede parsear y validar estructura minima del blob v2 sin acceder a secretos en claro.

## Implementacion por lotes

- Batch C1: agregar modelos y serializacion de blob v2 sin activar migracion.
- Batch C2: integrar KDF Argon2id + cifrado AES-GCM en flujo de alta/edicion.
- Batch C3: migrador controlado v1->v2 con telemetria de errores y rollback logico.
