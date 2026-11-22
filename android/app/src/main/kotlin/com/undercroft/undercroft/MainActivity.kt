package com.undercroft.undercroft

import android.os.Bundle
import android.view.WindowManager
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// plugin can present the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE blanks the recents thumbnail (which is how Android hides
        // the app-switcher snapshot) and blocks screenshots. Needed because
        // Android has no equivalent of the iOS blur-overlay approach.
        // Only applied in release builds so that debug builds can capture
        // screenshots for store listings and testing.
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }
}
