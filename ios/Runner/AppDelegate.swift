import UIKit
import Flutter
import flutter_downloader


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    FlutterDownloaderPlugin.setPluginRegistrantCallback({ registry in
      FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "vn.hunghd.flutter_downloader")!)
    })
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

}
