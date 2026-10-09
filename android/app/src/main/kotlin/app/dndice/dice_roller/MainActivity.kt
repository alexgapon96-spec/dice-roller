package app.dndice.dice_roller

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Media volume ignores silent/vibrate mode, so the app asks explicitly.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dice_roller/ringer")
            .setMethodCallHandler { call, result ->
                if (call.method == "isSilent") {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(audio.ringerMode != AudioManager.RINGER_MODE_NORMAL)
                } else {
                    result.notImplemented()
                }
            }
    }
}
