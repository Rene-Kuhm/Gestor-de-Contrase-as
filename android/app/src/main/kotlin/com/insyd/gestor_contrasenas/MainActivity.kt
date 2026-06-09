package com.insyd.gestor_contrasenas

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and the BiometricPrompt used to authorize
 * KeyStore private-key operations.
 *
 * The activity extends [FlutterFragmentActivity] (not the default
 * [io.flutter.embedding.android.FlutterActivity]) so the
 * [BiometricPrompt] fragment can attach.
 *
 * Best-practice notes (androidx.biometric 1.2.0-alpha05 + Android 14/15):
 *   * We use `BIOMETRIC_STRONG or DEVICE_CREDENTIAL` so the user
 *     always has a path: strong biometric when available, otherwise
 *     the device PIN/pattern/password. Strong-only is a common source
 *     of "the button vanished" bugs on devices that only expose a
 *     face-unlock hardware (which Android classifies as WEAK).
 *   * `setNegativeButtonText` is mutually exclusive with
 *     DEVICE_CREDENTIAL — the system uses its own fallback label.
 *   * Every error path is mapped to a stable string code that the
 *     Dart side can switch on, and every code we hit is logged with
 *     the `[Vaulta/Biometric]` prefix for adb logcat diagnosis.
 *   * When the platform reports BIOMETRIC_ERROR_NONE_ENROLLED we
 *     return the [BiometricErrorCode.NONE_ENROLLED] code. The Dart
 *     side turns that into an intent to
 *     [Settings.ACTION_BIOMETRIC_ENROLL] so the user can configure
 *     a fingerprint/face without leaving the app flow.
 */
class MainActivity : FlutterFragmentActivity() {

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCiphertext: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        KeystoreChannel(flutterEngine)
        BiometricChannel(
            flutterEngine,
            this::authenticateAndDecrypt,
            this::probeAvailability,
            this::openBiometricEnrollment,
        )
    }

    // ---- Public helpers exposed to the BiometricChannel ----

    /**
     * Returns a structured description of what the platform can do,
     * mirroring the [KeystoreChannel.probeAvailability] shape so Dart
     * can decide whether to show the unlock button at all.
     */
    private fun probeAvailability(): Map<String, Any> {
        val manager = BiometricManager.from(this)
        val strongCode = manager.canAuthenticate(Authenticators.BIOMETRIC_STRONG)
        val weakCode = manager.canAuthenticate(Authenticators.BIOMETRIC_WEAK)
        val strongOrCredCode = manager.canAuthenticate(
            Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL
        )
        val credOnlyCode = manager.canAuthenticate(Authenticators.DEVICE_CREDENTIAL)

        val result = mapOf(
            "strong" to biometricCodeName(strongCode),
            "weak" to biometricCodeName(weakCode),
            "strongOrCredential" to biometricCodeName(strongOrCredCode),
            "deviceCredential" to biometricCodeName(credOnlyCode),
            "strongCode" to strongCode,
            "weakCode" to weakCode,
            "strongOrCredentialCode" to strongOrCredCode,
            "deviceCredentialCode" to credOnlyCode,
            "canUseStrong" to (strongCode == BiometricManager.BIOMETRIC_SUCCESS),
            "canUseWeak" to (weakCode == BiometricManager.BIOMETRIC_SUCCESS),
            "canUseStrongOrCredential" to (strongOrCredCode == BiometricManager.BIOMETRIC_SUCCESS),
            "canUseDeviceCredential" to (credOnlyCode == BiometricManager.BIOMETRIC_SUCCESS),
        )
        Log.i(
            TAG,
            "probeAvailability strong=${result["strong"]} " +
                "weak=${result["weak"]} " +
                "strongOrCredential=${result["strongOrCredential"]} " +
                "deviceCredential=${result["deviceCredential"]}"
        )
        return result
    }

    /**
     * Opens the system biometric-enrollment settings. Dart calls this
     * after observing [BiometricErrorCode.NONE_ENROLLED]. We pass
     * [Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED] so the
     * settings page only shows options compatible with the
     * authenticators we actually use.
     *
     * Returns true if an enrollment activity was launched.
     */
    private fun openBiometricEnrollment(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                    putExtra(
                        Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                        Authenticators.BIOMETRIC_STRONG or
                            Authenticators.DEVICE_CREDENTIAL
                    )
                }
            } else {
                // Pre-Android 11 fallback — there is no dedicated
                // ACTION_BIOMETRIC_ENROLL, so we open the security
                // settings page. The user can find fingerprint setup
                // from there.
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            Log.i(TAG, "openBiometricEnrollment: launched system settings")
            true
        } catch (e: Throwable) {
            Log.w(TAG, "openBiometricEnrollment: no activity handled the intent", e)
            false
        }
    }

    // ---- Auth bridge ----

    /**
     * Bridges the `BiometricChannel.authenticateAndDecrypt` Dart call
     * into a real [BiometricPrompt]. The prompt is per-operation:
     * each call opens a fresh system dialog and only authorizes the
     * single KeyStore decrypt that follows it.
     *
     * The authenticator set is `BIOMETRIC_STRONG or DEVICE_CREDENTIAL`
     * (see class docs for why). When neither is available, we return
     * [BiometricErrorCode.UNAVAILABLE] with a precise cause so the
     * Dart side can render a specific message.
     */
    private fun authenticateAndDecrypt(
        ciphertext: ByteArray,
        result: MethodChannel.Result
    ) {
        if (pendingResult != null) {
            result.error(
                BiometricErrorCode.BUSY,
                "A biometric prompt is already in progress.",
                null
            )
            return
        }

        val manager = BiometricManager.from(this)
        val authenticators =
            Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL
        val canAuthenticate = manager.canAuthenticate(authenticators)
        if (canAuthenticate != BiometricManager.BIOMETRIC_SUCCESS) {
            val code = mapCanAuthenticateCodeToError(canAuthenticate)
            Log.w(
                TAG,
                "authenticateAndDecrypt rejected before prompt: " +
                    "platformCode=${biometricCodeName(canAuthenticate)} " +
                    "($canAuthenticate) -> $code"
            )
            result.error(code, canAuthenticateReason(canAuthenticate), canAuthenticate)
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

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    val r = pendingResult
                    pendingResult = null
                    pendingCiphertext = null
                    val code = mapPromptErrorToCode(errorCode)
                    Log.w(
                        TAG,
                        "onAuthenticationError: code=${promptErrorName(errorCode)} " +
                            "($errorCode) -> $code : $errString"
                    )
                    r?.error(code, errString.toString(), errorCode)
                }

                override fun onAuthenticationFailed() {
                    // Single attempt failed. The user can retry inside
                    // the system prompt; we do not resolve the result
                    // here. We log it so logcat shows the failing
                    // finger / face.
                    Log.d(TAG, "onAuthenticationFailed: single attempt rejected")
                }
            }
        )

        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.vaulta_biometric_prompt_title))
            .setSubtitle(getString(R.string.vaulta_biometric_prompt_subtitle))
            .setDescription(getString(R.string.vaulta_biometric_prompt_description))
            // setNegativeButtonText is mutually exclusive with
            // DEVICE_CREDENTIAL — the system renders its own fallback
            // button ("Use PIN" / "Use pattern" / "Use password").
            .setAllowedAuthenticators(authenticators)
            .setConfirmationRequired(false)
            .build()

        prompt.authenticate(info)
    }

    // ---- Error mapping ----

    private fun mapCanAuthenticateCodeToError(code: Int): String = when (code) {
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
            BiometricErrorCode.NO_HARDWARE
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
            BiometricErrorCode.HARDWARE_UNAVAILABLE
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
            BiometricErrorCode.NONE_ENROLLED
        BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
            BiometricErrorCode.SECURITY_UPDATE_REQUIRED
        BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED ->
            BiometricErrorCode.UNSUPPORTED
        BiometricManager.BIOMETRIC_STATUS_UNKNOWN ->
            BiometricErrorCode.UNAVAILABLE
        else -> BiometricErrorCode.UNAVAILABLE
    }

    private fun canAuthenticateReason(code: Int): String = when (code) {
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE ->
            getString(R.string.vaulta_biometric_error_no_hardware)
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE ->
            getString(R.string.vaulta_biometric_error_hw_unavailable)
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
            getString(R.string.vaulta_biometric_error_none_enrolled)
        BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
            getString(R.string.vaulta_biometric_error_security_update_required)
        BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED ->
            getString(R.string.vaulta_biometric_error_unsupported)
        else ->
            getString(R.string.vaulta_biometric_error_unknown)
    }

    private fun mapPromptErrorToCode(code: Int): String = when (code) {
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> BiometricErrorCode.HARDWARE_UNAVAILABLE
        BiometricPrompt.ERROR_UNABLE_TO_PROCESS -> BiometricErrorCode.UNAVAILABLE
        BiometricPrompt.ERROR_TIMEOUT -> BiometricErrorCode.TIMEOUT
        BiometricPrompt.ERROR_NO_SPACE -> BiometricErrorCode.UNAVAILABLE
        BiometricPrompt.ERROR_CANCELED -> BiometricErrorCode.USER_CANCELLED
        BiometricPrompt.ERROR_LOCKOUT -> BiometricErrorCode.LOCKOUT
        BiometricPrompt.ERROR_VENDOR -> BiometricErrorCode.UNAVAILABLE
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT ->
            BiometricErrorCode.LOCKOUT_PERMANENT
        BiometricPrompt.ERROR_USER_CANCELED -> BiometricErrorCode.USER_CANCELLED
        BiometricPrompt.ERROR_NO_BIOMETRICS -> BiometricErrorCode.NONE_ENROLLED
        BiometricPrompt.ERROR_HW_NOT_PRESENT -> BiometricErrorCode.NO_HARDWARE
        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> BiometricErrorCode.USER_CANCELLED
        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL ->
            BiometricErrorCode.NO_DEVICE_CREDENTIAL
        else -> BiometricErrorCode.UNAVAILABLE
    }

    private fun biometricCodeName(code: Int): String = when (code) {
        BiometricManager.BIOMETRIC_SUCCESS -> "SUCCESS"
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "NO_HARDWARE"
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "HW_UNAVAILABLE"
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "NONE_ENROLLED"
        BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED ->
            "SECURITY_UPDATE_REQUIRED"
        BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED -> "UNSUPPORTED"
        BiometricManager.BIOMETRIC_STATUS_UNKNOWN -> "STATUS_UNKNOWN"
        else -> "UNKNOWN($code)"
    }

    private fun promptErrorName(code: Int): String = when (code) {
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "HW_UNAVAILABLE"
        BiometricPrompt.ERROR_UNABLE_TO_PROCESS -> "UNABLE_TO_PROCESS"
        BiometricPrompt.ERROR_TIMEOUT -> "TIMEOUT"
        BiometricPrompt.ERROR_NO_SPACE -> "NO_SPACE"
        BiometricPrompt.ERROR_CANCELED -> "CANCELED"
        BiometricPrompt.ERROR_LOCKOUT -> "LOCKOUT"
        BiometricPrompt.ERROR_VENDOR -> "VENDOR"
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "LOCKOUT_PERMANENT"
        BiometricPrompt.ERROR_USER_CANCELED -> "USER_CANCELED"
        BiometricPrompt.ERROR_NO_BIOMETRICS -> "NO_BIOMETRICS"
        BiometricPrompt.ERROR_HW_NOT_PRESENT -> "HW_NOT_PRESENT"
        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "NEGATIVE_BUTTON"
        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "NO_DEVICE_CREDENTIAL"
        else -> "UNKNOWN($code)"
    }

    companion object {
        private const val TAG = "Vaulta/Biometric"
    }
}

/**
 * Stable string codes returned across the biometric MethodChannel.
 *
 * Keeping them in one place means the Dart side can `switch` on the
 * `PlatformException.code` without depending on AndroidX-internal
 * integer codes that have shifted between releases.
 */
object BiometricErrorCode {
    /** Another prompt is already in flight. */
    const val BUSY = "BIOMETRIC_BUSY"

    /** Platform reports no biometric hardware at all. */
    const val NO_HARDWARE = "BIOMETRIC_NO_HARDWARE"

    /** Hardware exists but is temporarily unavailable (sensor dirty, etc.). */
    const val HARDWARE_UNAVAILABLE = "BIOMETRIC_HW_UNAVAILABLE"

    /** No biometric is enrolled. Dart should offer the enrollment intent. */
    const val NONE_ENROLLED = "BIOMETRIC_NONE_ENROLLED"

    /** Platform reported no PIN/pattern/password on the device. */
    const val NO_DEVICE_CREDENTIAL = "BIOMETRIC_NO_DEVICE_CREDENTIAL"

    /** OS-level security patch is required before biometrics work. */
    const val SECURITY_UPDATE_REQUIRED =
        "BIOMETRIC_SECURITY_UPDATE_REQUIRED"

    /** The platform does not support the requested authenticator set. */
    const val UNSUPPORTED = "BIOMETRIC_UNSUPPORTED"

    /** Generic unavailability — used as a last-resort catch-all. */
    const val UNAVAILABLE = "BIOMETRIC_UNAVAILABLE"

    /** Short transient lockout after too many failed attempts. */
    const val LOCKOUT = "BIOMETRIC_LOCKOUT"

    /** Long/permanent lockout — user must re-enroll or wait significantly. */
    const val LOCKOUT_PERMANENT = "BIOMETRIC_LOCKOUT_PERMANENT"

    /** The system prompt timed out. */
    const val TIMEOUT = "BIOMETRIC_TIMEOUT"

    /** The user dismissed the prompt (cancel, negative button, etc.). */
    const val USER_CANCELLED = "USER_CANCELLED"
}
