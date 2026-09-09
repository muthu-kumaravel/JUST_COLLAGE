import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let channel = FlutterMethodChannel(name: "com.justcollage.heic", binaryMessenger: messenger)
      channel.setMethodCallHandler { (call, result) in
        if call.method == "convertHeicToJpeg" {
          guard let args = call.arguments as? [String: Any],
                let flutterData = args["data"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
            return
          }
          let data = flutterData.data
          guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            result(FlutterError(code: "DECODE_FAILED", message: "Failed to decode image data with ImageIO", details: nil))
            return
          }
          let outputData = NSMutableData()
          guard let destination = CGImageDestinationCreateWithData(outputData as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            result(FlutterError(code: "ENCODE_FAILED", message: "Failed to create JPEG destination", details: nil))
            return
          }
          let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.95
          ]
          CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
          if CGImageDestinationFinalize(destination) {
            result(FlutterStandardTypedData(bytes: outputData as Data))
          } else {
            result(FlutterError(code: "FINALIZE_FAILED", message: "Failed to finalize JPEG", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
