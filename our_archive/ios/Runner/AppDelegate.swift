import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if FirebaseApp.app() == nil {
        print("🔥 FIREBASE NOT INITIALIZED IN NATIVE")
    } else {
        print("🔥 FIREBASE OK: \(FirebaseApp.app()!)")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
