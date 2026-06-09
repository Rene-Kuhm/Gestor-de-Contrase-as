package com.insyd.gestor_contrasenas

import android.os.Build
import android.os.Bundle
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and the BiometricPrompt used to authorize
 * KeyStore private-key operations. We extend [FlutterFragmentActivity]
 * (not the default [io.flutter.embedding.android.FlutterActivity]) so
 * the [BiometricPrompt] fragment can attach.
 */
class MainActivity : FlutterFragmentActivity() {

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCiphertext: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        KeystoreChannel(flutterEngine)
        BiometricChannel(flutterEngine, this::authenticateAndDecrypt)
    }

    /**
     * Bridges the `BiometricChannel.authenticateAndDecrypt` Dart call
     * into a real [BiometricPrompt]. The prompt is per-operation: each
     * call opens a fresh system dialog and only authorizes the
     * single KeyStore decrypt that follows it.
     */
    private fun authenticateAndDecrypt(
        ciphertext: ByteArray,
        result: MethodChannel.Result
    ) {
        // If another prompt is already in flight, reject the new one
        // to keep the bridge serial. The Dart side waits on the
        // existing future.
        if (pendingResult != null) {
            result.error("BUSY", "A biometric prompt is already in progress.", null)
            return
        }

        val manager = BiometricManager.from(this)
        val canAuthenticate = manager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        )
        if (canAuthenticate != BiometricManager.BIOMETRIC_SUCCESS) {
            result.error(
                "BIOMETRIC_UNAVAILABLE",
                "Strong biometrics are not available on this device.",
                null
            )
            return
        }

        pendingResult = result
        pendingCiphertext = ciphertext

        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authResult: BiometricPrompt.AuthenticationResult
                ) {
                    val r = pendingResult
                    val ct = pendingCiphertext
                    pendingResult = null
                    pendingCiphertext = null
                    if (r == null || ct == null) return

                    // The KeyStore private key is now authorized for
                    // the rest of this process lifetime (or until the
                    // user locks the device). We hand the ciphertext
                    // back to the Dart side, which forwards it to
                    // `rsaDecryptAuthorized` and returns the seed.
                    r.success(ct)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val r = pendingResult
                    pendingResult = null
                    pendingCiphertext = null
                    r?.error(
                        when (errorCode) {
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_CANCELED -> "USER_CANCELLED"
                            else -> "BIOMETRIC_ERROR"
                        },
                        errString.toString(),
                        null
                    )
                }

                override fun onAuthenticationFailed() {
                    // Single attempt failed. The user can retry inside
                    // the system prompt; we do not resolve the result
                    // here.
                }
            }
        )

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Desbloquear Vaulta")
            .setSubtitle("Confirma tu identidad para recuperar tu sesion")
            .setDescription("La biometria protege la clave que cifra tu vault.")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()

        prompt.authenticate(info)
    }
}
