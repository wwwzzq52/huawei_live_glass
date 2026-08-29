package com.cloudmind.flutter_live_motion

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.UUID

/** FlutterLiveMotionPlugin */
class FlutterLiveMotionPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: android.content.Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_live_motion")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "generate") {
            val imagePath = call.argument<String>("imagePath")
            val videoPath = call.argument<String>("videoPath")

            if (imagePath == null || videoPath == null) {
                result.error("INVALID_ARGUMENTS", "imagePath and videoPath are required", null)
                return
            }

            try {
                val outputDir = context.cacheDir
                // Ensure filename ends with MP.jpg for better compatibility with Samsung/Realme/etc.
                val outputFile = File(outputDir, "MVIMG_${UUID.randomUUID()}_MP.jpg")

                // 使用 1:1 HTML 移植版本
                MotionPhotoGeneratorHtml.generate(
                    imagePath = imagePath,
                    videoPath = videoPath,
                    outputPath = outputFile.absolutePath
                )
                result.success(outputFile.absolutePath)
            } catch (e: Exception) {
                result.error("GENERATION_FAILED", e.message, null)
            }
        } else if (call.method == "export") {
            // 【修改点 A：新增 export 方法，支持华为配对导出】
            val imagePath = call.argument<String>("imagePath")
            val videoPath = call.argument<String>("videoPath")
            val mode = call.argument<String>("mode") ?: "auto"

            if (imagePath == null || videoPath == null) {
                result.error("INVALID_ARGUMENTS", "imagePath and videoPath are required", null)
                return
            }

            try {
                val out = HuaweiMotionPhotoExporter.export(
                    context = context,
                    imagePath = imagePath,
                    videoPath = videoPath,
                    mode = mode
                )
                result.success(
                    mapOf(
                        "image" to out.imagePath,
                        "video" to out.videoPath,
                        "motionPhoto" to out.motionPhotoPath
                    )
                )
            } catch (e: Exception) {
                result.error("EXPORT_FAILED", e.message, null)
            }
        } else if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
