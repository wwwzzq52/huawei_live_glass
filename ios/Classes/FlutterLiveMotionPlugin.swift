import Flutter
import UIKit

public class FlutterLiveMotionPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_live_motion", binaryMessenger: registrar.messenger())
    let instance = FlutterLiveMotionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generate":
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String,
              let videoPath = args["videoPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "imagePath and videoPath are required", details: nil))
            return
        }
        
        LivePhotoGenerator.generate(imagePath: imagePath, videoPath: videoPath) { success, error in
            if success {
                result(true)
            } else {
                result(FlutterError(code: "GENERATION_FAILED", message: error?.localizedDescription, details: nil))
            }
        }
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
