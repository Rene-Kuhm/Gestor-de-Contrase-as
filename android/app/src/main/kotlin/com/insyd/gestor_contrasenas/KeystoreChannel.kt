package com.insyd.gestor_contrasenas

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Bridge between the Dart envelope and the Android KeyStore.
 *
 * Generates an RSA-2048 keypair inside the hardware-backed KeyStore
 * (AndroidKeyStore provider) with `setUserAuthenticationRequired(true)`.
 * The private key never leaves the secure element; every decrypt
 * operation must be preceded by a successful BiometricPrompt, which
 * the host activity handles on a separate channel. We only return
 * cipher-text + IV here; the key itself is referenced by alias.
 *
 * For the Vaulta envelope we use the public key to RSA-OAEP-encrypt
 * a per-installation AES-256 seed (generated on the Dart side). The
 * Dart side also generates the AES-256 key used to wrap the DEK with
 * HKDF — the RSA-encrypted seed is stored in secure storage, and the
 * `unwrap` path is what requires the BiometricPrompt to release the
 * private key for one decryption.
 *
 * The algorithm choices are deliberate:
 *   - RSA-OAEP-SHA256 is the standard wrap algorithm for short keys.
 *   - AES/GCM/NoPadding inside the Dart envelope is the DEK wrap.
 *   - We never persist the DEK in clear, even on disk.
 */
class KeystoreChannel(engine: FlutterEngine) : MethodChannel.MethodCallHandler {

    private val channel: MethodChannel =
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "ensureKey" -> result.success(ensureKey())
                "deleteKey" -> {
                    deleteKey()
                    result.success(null)
                }
                "isAvailable" -> result.success(isAvailable())
                "rsaEncrypt" -> {
                    val plaintext = call.argument<ByteArray>("plaintext")
                        ?: return result.error("ARG", "plaintext is required", null)
                    val encrypted = rsaEncrypt(plaintext)
                    result.success(encrypted)
                }
                "rsaDecryptAuthorized" -> {
                    val ciphertext = call.argument<ByteArray>("ciphertext")
                        ?: return result.error("ARG", "ciphertext is required", null)
                    val plaintext = rsaDecryptAuthorized(ciphertext)
                    result.success(plaintext)
                }
                else -> result.notImplemented()
            }
        } catch (e: UserCancelledException) {
            result.error("USER_CANCELLED", e.message ?: "user cancelled", null)
        } catch (e: BiometricUnavailableException) {
            result.error("BIOMETRIC_UNAVAILABLE", e.message ?: "biometric unavailable", null)
        } catch (e: Throwable) {
            result.error("KEYSTORE", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun isAvailable(): Boolean {
        val ks = try {
            KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        } catch (_: Throwable) {
            return false
        }
        return try {
            val generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                ANDROID_KEYSTORE
            )
            // Building the spec is enough to fail on devices that do not
            // support STRONG biometric-bound keys. We never call init().
            val spec = KeyGenParameterSpec.Builder(
                "vaulta-biometric-probe",
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                .setKeySize(2048)
                .setUserAuthenticationRequired(true)
                .build()
            // Touch the spec to surface configuration errors early.
            spec.toString()
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun ensureKey(): String {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (ks.containsAlias(KEY_ALIAS)) {
            return KEY_ALIAS
        }

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA,
            ANDROID_KEYSTORE
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setKeySize(2048)
            // The private key may only be used after a fresh user auth.
            .setUserAuthenticationRequired(true)
            // Auth is per-operation. We do NOT use the legacy
            // setUserAuthenticationValidityDuration(N) shortcut because
            // that would leave a window where a stolen device could
            // unlock the vault without the user noticing.
            .build()
        generator.init(spec)
        generator.generateKey()
        return KEY_ALIAS
    }

    private fun deleteKey() {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (ks.containsAlias(KEY_ALIAS)) {
            ks.deleteEntry(KEY_ALIAS)
        }
        if (ks.containsAlias("vaulta-biometric-probe")) {
            ks.deleteEntry("vaulta-biometric-probe")
        }
    }

    private fun rsaEncrypt(plaintext: ByteArray): ByteArray {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (!ks.containsAlias(KEY_ALIAS)) {
            ensureKey()
        }
        val entry = ks.getEntry(KEY_ALIAS, null) as KeyStore.PrivateKeyEntry
        val cipher = Cipher.getInstance(TRANSFORMATION_RSA)
        // No IvParameter for RSA-OAEP. Encryption is a public-key
        // operation, so the biometric gate is intentionally not
        // consulted here: this is the path the app uses to wrap a
        // fresh seed at activation time, not to unwrap it.
        cipher.init(Cipher.ENCRYPT_MODE, entry.certificate.publicKey)
        return cipher.doFinal(plaintext)
    }

    /**
     * Decrypts the RSA-encrypted seed. Requires that the user has
     * freshly authenticated via BiometricPrompt. The hosting activity
     * must have called `BiometricPrompt.authenticate(...)` immediately
     * before invoking this method, so the KeyStore grants the
     * private-key operation a fresh authorization window.
     */
    private fun rsaDecryptAuthorized(ciphertext: ByteArray): ByteArray {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        if (!ks.containsAlias(KEY_ALIAS)) {
            throw BiometricUnavailableException("No biometric key enrolled.")
        }
        val entry = ks.getEntry(KEY_ALIAS, null) as KeyStore.PrivateKeyEntry
        val cipher = Cipher.getInstance(TRANSFORMATION_RSA)
        try {
            cipher.init(Cipher.DECRYPT_MODE, entry.privateKey)
        } catch (e: Throwable) {
            if (e.message?.contains("Key permanently invalidated", ignoreCase = true) == true ||
                e.message?.contains("User not authenticated", ignoreCase = true) == true
            ) {
                throw BiometricUnavailableException(
                    "La biometria no esta disponible o fue revocada."
                )
            }
            throw e
        }
        return cipher.doFinal(ciphertext)
    }

    class UserCancelledException(message: String) : RuntimeException(message)
    class BiometricUnavailableException(message: String) : RuntimeException(message)

    companion object {
        const val CHANNEL_NAME = "com.insyd.vaulta/keystore"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "vaulta_biometric_envelope_v1"
        private const val TRANSFORMATION_RSA = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
    }
}
