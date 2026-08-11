package com.brahma.brahmaApp

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridges the Flutter side cannot do itself.
 *
 *  * `secure_window` — FLAG_SECURE, applied to the whole app in onCreate.
 *
 * There used to be a second channel here, `installer`, which handed a
 * downloaded APK to Android's package installer. It is gone: Google Play does
 * not permit an app to update itself by any route other than Play's own, and
 * the REQUEST_INSTALL_PACKAGES permission it needed is an automatic rejection.
 * Updates now open the store listing. See AppUpdateService on the Dart side.
 */
class MainActivity : FlutterActivity() {
    private val secureChannel = "com.brahma.brahmaApp/secure_window"

    companion object {
        /**
         * Whether the app may be screenshotted and screen-recorded.
         *
         * Tied to the build type rather than to a hand-flipped constant, and
         * that is the point: **a release build is always protected**, so there
         * is no longer a way to ship an unprotected one by forgetting to change
         * something back.
         *
         * Debug builds are capturable, which is what makes store screenshots
         * and a walkthrough recording possible — with FLAG_SECURE on, the
         * system refuses the screenshot outright and a screen recording comes
         * out black. Debug builds are never distributed; App Distribution and
         * the Play Store both get release builds.
         *
         * The same rule is expressed in two other places, because each runs
         * before the others exist:
         *   * `ScreenSecurity.allowScreenCapture` in ios/Runner/AppDelegate.swift
         *   * `AppConstants.allowScreenCapture` in lib/core/constants/app_constants.dart
         */
        val ALLOW_SCREEN_CAPTURE = BuildConfig.DEBUG
    }

    /**
     * Applies FLAG_SECURE to the whole app unless capture is allowed.
     *
     * Journal entries, check-ins, anonymous thoughts and counselling threads
     * are the most private things in here, so protection is app-wide rather
     * than bolted onto the book reader — which was the least personal screen in
     * the app and, before this, the only protected one.
     *
     * Set before super.onCreate so the flag is in place before the first frame
     * is ever composited; a window can otherwise be captured in the gap.
     *
     * What it does when on: the system refuses the screenshot ("Can't take
     * screenshot due to security policy"), recordings and casts show black, and
     * the app switcher shows a blank card. What it cannot do: stop a second
     * phone pointed at the screen. Nothing on any platform can.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        if (!ALLOW_SCREEN_CAPTURE) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The PDF reader asks for this on the way in. While capture
                    // is allowed it is answered rather than obeyed: honouring it
                    // would black out the one screen a promo video most wants to
                    // show, from a call the Dart side makes for a different
                    // reason entirely.
                    "enable" -> {
                        if (!ALLOW_SCREEN_CAPTURE) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE,
                            )
                        }
                        result.success(!ALLOW_SCREEN_CAPTURE)
                    }
                    // Deliberately does NOT clear the flag when protection is
                    // on. It is app-wide, so honouring a "disable" from one
                    // screen would quietly unprotect every screen behind it.
                    "disable" -> result.success(true)
                    else -> result.notImplemented()
                }
            }

    }
}
