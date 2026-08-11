import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ScreenSecurity.shared.start()
    // Pre-scene launch path still owns a window here; the scene path attaches
    // from SceneDelegate instead. Whichever fires first wins, the other no-ops.
    if let window = self.window {
      ScreenSecurity.shared.harden(window)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Screenshot and screen-recording protection for iOS.
///
/// Android has FLAG_SECURE, which asks the system to refuse the capture. iOS
/// has no such flag, so this uses the two things that are actually available:
///
///  1. **The secure-field layer.** A `UITextField` with `isSecureTextEntry` on
///     renders its contents normally on screen but is excluded from the buffer
///     the system reads for screenshots and recordings. Re-parenting the app
///     window's layer inside that field's layer extends the exclusion to the
///     whole app, so a screenshot comes out blank while the user still sees
///     everything. It is a documented behaviour of the secure field rather than
///     a supported API, so every step is guarded and any failure simply falls
///     through to (2) rather than crashing or blanking the real screen.
///
///  2. **A cover view.** Drawn over everything whenever the screen is being
///     captured — recording, AirPlay, a mirrored display — and whenever the app
///     leaves the foreground, which is what keeps journal text out of the app
///     switcher preview.
///
/// Neither stops a second phone pointed at the screen. Nothing does.
final class ScreenSecurity {
  static let shared = ScreenSecurity()

  /// Whether the app may be screenshotted and screen-recorded.
  ///
  /// Tied to the build configuration rather than to a hand-flipped constant,
  /// and that is the point: **a release build is always protected**, so there
  /// is no longer a way to ship an unprotected one by forgetting to change
  /// something back.
  ///
  /// Debug builds are capturable, which is what makes store screenshots and a
  /// walkthrough recording possible — with protection on, a screen recording of
  /// this app is a black rectangle and the app switcher shows a blank card.
  /// Debug builds are never distributed.
  ///
  /// The same rule is expressed in two other places, because each runs before
  /// the others exist:
  ///   * `MainActivity.ALLOW_SCREEN_CAPTURE` in
  ///     android/app/src/main/kotlin/com/brahma/brahmaApp/MainActivity.kt
  ///   * `AppConstants.allowScreenCapture` in
  ///     lib/core/constants/app_constants.dart
  static let allowScreenCapture: Bool = {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }()

  private let secureField = UITextField()
  private weak var window: UIWindow?
  private var cover: UIView?
  private var hardened = false

  private init() {}

  func start() {
    // Nothing is observed while capture is allowed: the cover view is driven by
    // these notifications, so not registering them is what keeps the screen
    // visible during a recording rather than replaced by a dark card.
    guard Self.allowScreenCapture == false else { return }

    let centre = NotificationCenter.default
    centre.addObserver(
      self, selector: #selector(captureStateChanged),
      name: UIScreen.capturedDidChangeNotification, object: nil)
    centre.addObserver(
      self, selector: #selector(willLeaveForeground),
      name: UIApplication.willResignActiveNotification, object: nil)
    centre.addObserver(
      self, selector: #selector(didEnterForeground),
      name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  /// Attaches to the app window. Safe to call more than once.
  func harden(_ window: UIWindow) {
    // The secure-field trick is what excludes the app from the screenshot
    // buffer, so skipping it is the whole of "allow capture" on iOS.
    guard Self.allowScreenCapture == false else { return }

    self.window = window
    guard !hardened else { return }

    secureField.isSecureTextEntry = true
    secureField.isUserInteractionEnabled = false
    secureField.backgroundColor = .clear
    secureField.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(secureField)
    NSLayoutConstraint.activate([
      secureField.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      secureField.centerYAnchor.constraint(equalTo: window.centerYAnchor),
    ])

    // The field's own backing layer is what the system excludes. Moving it up
    // beside the window and then hanging the window's layer beneath it puts
    // every pixel the app draws inside the excluded subtree.
    guard let host = window.layer.superlayer else { return }
    host.addSublayer(secureField.layer)

    // iOS 17 reordered the field's internal sublayers; picking the wrong one
    // detaches the app's UI from the screen entirely, so bail out rather than
    // guess. The cover view still protects the app if this does not apply.
    let target: CALayer?
    if #available(iOS 17.0, *) {
      target = secureField.layer.sublayers?.last
    } else {
      target = secureField.layer.sublayers?.first
    }
    guard let target else { return }
    target.addSublayer(window.layer)

    hardened = true
    captureStateChanged()
  }

  // MARK: - cover view

  @objc private func captureStateChanged() {
    setCoverVisible(UIScreen.main.isCaptured, message: "Screen recording is not allowed here")
  }

  @objc private func willLeaveForeground() {
    setCoverVisible(true, message: nil)
  }

  @objc private func didEnterForeground() {
    setCoverVisible(UIScreen.main.isCaptured, message: "Screen recording is not allowed here")
  }

  private func setCoverVisible(_ visible: Bool, message: String?) {
    guard let window else { return }

    if !visible {
      cover?.removeFromSuperview()
      cover = nil
      return
    }

    if cover == nil {
      let view = UIView(frame: window.bounds)
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      // Matches AppTheme.bgDark, so the cover reads as the app rather than as
      // a glitch when it appears in the app switcher.
      view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1)

      let label = UILabel()
      label.text = message ?? "Brahma Journal"
      label.textColor = UIColor(white: 1, alpha: 0.75)
      label.font = .systemFont(ofSize: 15, weight: .medium)
      label.textAlignment = .center
      label.numberOfLines = 0
      label.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(label)
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),
      ])

      window.addSubview(view)
      cover = view
    }

    if let cover {
      window.bringSubviewToFront(cover)
    }
  }
}
