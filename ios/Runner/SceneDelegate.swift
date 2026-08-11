import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Under the scene lifecycle the window belongs to the scene, not to the app
  /// delegate — so this is where screenshot protection has to be attached. It
  /// waits one runloop turn because Flutter builds its view controller inside
  /// super, and re-parenting a layer that does not exist yet does nothing.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    DispatchQueue.main.async { [weak self] in
      if let window = self?.window {
        ScreenSecurity.shared.harden(window)
      }
    }
  }
}
