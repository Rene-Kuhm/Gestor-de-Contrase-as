package com.insyd.gestor_contrasenas

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Coordinates the BiometricPrompt round-trip for the Dart envelope.
 *
 *   1. Dart calls `requestDecryptAuthorization(ciphertext)`.
 *   2. The host activity opens a BiometricPrompt.
 *   3. On success, the activity returns the ciphertext back to Dart.
 *   4. Dart forwards the ciphertext to KeystoreChannel
 *      `rsaDecryptAuthorized` and receives the seed.
 *
 * We do NOT forward the plaintext to the activity. The activity only
 * confirms "the user is here" — the actual RSA private-key operation
 * happens in the keystore helper, and the plaintext is materialized
 * only in Dart, where the envelope service unmarshals it into the
 * session key.
 */
class BiometricChannel(
    engine: FlutterEngine,
    private val onAuthenticate: (ciphertext: ByteArray, result: MethodChannel.Result) -> Unit
) : MethodChannel.MethodCallHandler {

    private val channel: MethodChannel =
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestDecryptAuthorization" -> {
                val ciphertext = call.argument<ByteArray>("ciphertext")
                if (ciphertext == null) {
                    result.error("ARG", "ciphertext is required", null)
                    return
                }
                onAuthenticate(ciphertext, result)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.insyd.vaulta/biometric"
    }
}
