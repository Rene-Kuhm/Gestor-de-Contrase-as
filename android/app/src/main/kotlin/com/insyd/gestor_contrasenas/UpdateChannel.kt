package com.insyd.gestor_contrasenas

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Over-the-air update bridge.
 *
 * On `push` to `master` a GitHub Actions workflow builds the APK
 * and publishes it as a GitHub Release with tag `dev-latest`. The
 * channel queries the public Releases API, downloads the APK to
 * the app's private files directory, and hands it off to the
 * system installer via FileProvider.
 *
 * The APK keeps the same debug signature across builds, so Android
 * accepts it as an in-place update — the user's master password,
 * envelope, and secure storage are preserved. No Play Store
 * involved.
 *
 * Methods exposed to Dart:
 *   * `checkForUpdate(owner, repo, currentVersion)` -> map describing
 *     whether a new release is available.
 *   * `downloadApk(apkUrl)` -> absolute file path to the cached APK.
 *   * `openInstallPrompt(filePath)` -> bool, true if the system
 *     installer was launched.
 */
class UpdateChannel(
    engine: FlutterEngine,
    private val appContext: Context,
) : MethodChannel.MethodCallHandler {

    private val channel: MethodChannel =
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "checkForUpdate" -> {
                    val owner = call.argument<String>("owner")
                    val repo = call.argument<String>("repo")
                    val currentVersion = call.argument<String>("currentVersion")
                    if (owner.isNullOrBlank() || repo.isNullOrBlank()) {
                        result.error("ARG", "owner and repo are required", null)
                        return
                    }
                    result.success(checkForUpdate(owner, repo, currentVersion))
                }
                "downloadApk" -> {
                    val apkUrl = call.argument<String>("apkUrl")
                    if (apkUrl.isNullOrBlank()) {
                        result.error("ARG", "apkUrl is required", null)
                        return
                    }
                    result.success(downloadApk(apkUrl))
                }
                "openInstallPrompt" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("ARG", "filePath is required", null)
                        return
                    }
                    result.success(openInstallPrompt(filePath))
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Method ${call.method} failed", e)
            result.error(
                "UPDATE_FAILED",
                e.message ?: e.javaClass.simpleName,
                null
            )
        }
    }

    // ---- checkForUpdate ----

    /**
     * Queries the GitHub Releases API for the `dev-latest` tag and
     * returns a structured map describing whether the user is up
     * to date. We only ever look at the `dev-latest` release, so
     * production-style release tags do not pollute the result.
     */
    private fun checkForUpdate(
        owner: String,
        repo: String,
        currentVersion: String?,
    ): Map<String, Any?> {
        val apiUrl = "https://api.github.com/repos/$owner/$repo/releases/tags/dev-latest"
        Log.d(TAG, "checkForUpdate: GET $apiUrl")
        val conn = (URL(apiUrl).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15_000
            readTimeout = 15_000
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "Vaulta-UpdateChannel/1.0")
        }
        try {
            val code = conn.responseCode
            if (code == 404) {
                Log.d(TAG, "checkForUpdate: no dev-latest release yet")
                return mapOf(
                    "available" to false,
                    "reason" to "no_release",
                    "currentVersion" to currentVersion,
                )
            }
            if (code !in 200..299) {
                Log.w(TAG, "checkForUpdate: GitHub returned HTTP $code")
                return mapOf(
                    "available" to false,
                    "reason" to "http_$code",
                    "currentVersion" to currentVersion,
                )
            }
            val body = conn.inputStream.bufferedReader().use { it.readText() }
            return parseRelease(body, currentVersion)
        } finally {
            conn.disconnect()
        }
    }

    private fun parseRelease(json: String, currentVersion: String?): Map<String, Any?> {
        val root = JSONObject(json)
        val tagName = root.optString("tag_name", "")
        val publishedAt = root.optString("published_at", "")
        val body = root.optString("body", "")

        // GitHub returns assets as a JSONArray. The APK is the only
        // file with .apk in the name we care about.
        val assets = root.optJSONArray("assets")
        var apkUrl: String? = null
        if (assets != null) {
            for (i in 0 until assets.length()) {
                val asset = assets.getJSONObject(i)
                val name = asset.optString("name", "")
                if (name.endsWith(".apk", ignoreCase = true)) {
                    apkUrl = asset.optString("browser_download_url", null)
                    if (apkUrl != null) break
                }
            }
        }
        if (apkUrl == null) {
            Log.w(TAG, "parseRelease: no .apk asset on release $tagName")
            return mapOf(
                "available" to false,
                "reason" to "no_apk_asset",
                "tagName" to tagName,
                "currentVersion" to currentVersion,
            )
        }

        // The Dart side keeps the last-seen tag in storage. We return
        // every field the UI needs to render an "Update available"
        // banner without making a second call.
        return mapOf(
            "available" to true,
            "tagName" to tagName,
            "apkUrl" to apkUrl,
            "changelog" to body,
            "publishedAt" to publishedAt,
            "currentVersion" to currentVersion,
        )
    }

    // ---- downloadApk ----

    /**
     * Streams the APK to filesDir/updates/<basename>.apk. Returns
     * the absolute file path so the Dart side can hand it back to
     * `openInstallPrompt` after the user taps install.
     */
    private fun downloadApk(apkUrl: String): String {
        Log.d(TAG, "downloadApk: GET $apkUrl")
        val conn = (URL(apkUrl).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 30_000
            readTimeout = 60_000
            setRequestProperty("User-Agent", "Vaulta-UpdateChannel/1.0")
        }
        try {
            val code = conn.responseCode
            if (code !in 200..299) {
                throw RuntimeException("APK download failed: HTTP $code")
            }
            val updatesDir = File(appContext.filesDir, "updates").apply { mkdirs() }
            val basename = apkUrl.substringAfterLast('/').ifBlank { "vaulta-update.apk" }
            val target = File(updatesDir, basename)
            conn.inputStream.use { input ->
                FileOutputStream(target).use { output ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        output.write(buf, 0, n)
                    }
                }
            }
            Log.d(TAG, "downloadApk: wrote ${target.length()} bytes to ${target.absolutePath}")
            return target.absolutePath
        } finally {
            conn.disconnect()
        }
    }

    // ---- openInstallPrompt ----

    /**
     * Opens the system install prompt for the previously downloaded
     * APK. On API 24+ we go through FileProvider so we can pass a
     * content:// URI to the system installer. Returns true if the
     * installer activity was launched.
     */
    private fun openInstallPrompt(filePath: String): Boolean {
        val file = File(filePath)
        if (!file.exists()) {
            Log.w(TAG, "openInstallPrompt: file does not exist: $filePath")
            return false
        }
        val authority = "${appContext.packageName}.fileprovider"
        val uri = try {
            FileProvider.getUriForFile(appContext, authority, file)
        } catch (e: Throwable) {
            Log.w(TAG, "openInstallPrompt: FileProvider failed", e)
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            appContext.startActivity(intent)
            Log.d(TAG, "openInstallPrompt: launched system installer for $filePath")
            true
        } catch (e: Throwable) {
            Log.w(TAG, "openInstallPrompt: no activity handled the intent", e)
            false
        }
    }

    companion object {
        private const val TAG = "Vaulta/Update"
        const val CHANNEL_NAME = "com.insyd.vaulta/update"
    }
}
