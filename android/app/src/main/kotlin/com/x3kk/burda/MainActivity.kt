package com.x3kk.burda

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Adds one thing to the standard Flutter activity: handing a downloaded apk to
 * Android's package installer, so the app can update itself from a GitHub
 * release without being uninstalled first.
 *
 * Nothing here installs anything on its own. It opens the installer, which
 * asks the user to allow installs from this app the first time and confirms
 * every time after that.
 */
class MainActivity : FlutterActivity() {
    private val channel = "burda/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> install(call.argument<String>("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("no_path", "No apk was named", null)
            return
        }

        val apk = File(path)
        if (!apk.exists()) {
            result.error("missing", "No apk at $path", null)
            return
        }

        try {
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.updates",
                apk,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }
}
