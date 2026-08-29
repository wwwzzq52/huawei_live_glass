package com.cloudmind.flutter_live_motion

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.util.UUID

/**
 * 【新增文件】华为动态照片导出器。
 *
 * 华为图库的“动态照片”采用「同名配对」方案：
 *   DCIM/Camera/IMG_xxx.jpg  +  DCIM/Camera/IMG_xxx.mp4
 * 两个文件同名（仅扩展名不同）且出现在同一相册目录时，图库会将其识别为一张
 * 动态照片，点开播放时读取同目录同名 MP4 作为动态片段。
 *
 * 因此本导出器只负责：
 *   1. 判定输出模式（standard / huaweiPair / auto）；
 *   2. huaweiPair：把“处理后的图片”与源视频按“同名”规则写入公共相册；
 *   3. standard：复用上游 MotionPhotoGeneratorHtml 生成视频内嵌的 MotionPhoto。
 *
 * 注意：
 *   - “处理后的图片”由调用方（Dart 端）渲染完成后传入 imagePath，本类不做图像处理；
 *   - 写入公共相册使用 MediaStore（API 29+）与 MediaScanner（旧版本）双通道，
 *     保证华为图库能立即发现新文件。
 */
class HuaweiMotionPhotoExporter private constructor(
    private val context: Context
) {

    /** 导出结果。videoPath / motionPhotoPath 按模式二选一，另一个为 null。 */
    data class ExportResult(
        val imagePath: String,
        val videoPath: String?,
        val motionPhotoPath: String?
    )

    companion object {

        private val RELATIVE_DIR =
            Environment.DIRECTORY_DCIM + File.separator + "Camera"

        fun export(
            context: Context,
            imagePath: String,
            videoPath: String,
            mode: String
        ): ExportResult {
            return HuaweiMotionPhotoExporter(context.applicationContext)
                .doExport(imagePath, videoPath, mode)
        }
    }

    private fun doExport(imagePath: String, videoPath: String, mode: String): ExportResult {
        val imageFile = File(imagePath)
        val videoFile = File(videoPath)

        if (!imageFile.exists() || !imageFile.isFile) {
            throw java.io.IOException("Image file does not exist: $imagePath")
        }
        if (!videoFile.exists() || !videoFile.isFile) {
            throw java.io.IOException("Video file does not exist: $videoPath")
        }

        // 【需求 1】auto 模式：识别华为动态照片 —— 同目录同名（.jpg / .mp4）
        val looksLikeHuaweiPair =
            imageFile.nameWithoutExtension.equals(videoFile.nameWithoutExtension, ignoreCase = true) &&
                    imageFile.parentFile?.absolutePath == videoFile.parentFile?.absolutePath &&
                    (imageFile.extension.equals("jpg", ignoreCase = true) ||
                            imageFile.extension.equals("jpeg", ignoreCase = true)) &&
                    videoFile.extension.equals("mp4", ignoreCase = true)

        val resolvedMode = when (mode) {
            "huaweiPair" -> "huaweiPair"
            "standard" -> "standard"
            else -> if (looksLikeHuaweiPair) "huaweiPair" else "standard"
        }

        return if (resolvedMode == "huaweiPair") {
            exportHuaweiPair(imageFile, videoFile)
        } else {
            exportStandardMotionPhoto(imageFile, videoFile)
        }
    }

    /** 【需求 2 — 开启】图片 + 同名 mp4，写入公共相册，华为图库可识别播放。 */
    private fun exportHuaweiPair(imageFile: File, videoFile: File): ExportResult {
        val baseName = "IMG_${System.currentTimeMillis()}"

        // 先落盘到应用缓存，再通过 MediaStore / MediaScanner 登记进公共相册。
        // 同名规则：仅扩展名不同。
        val outImagePath = writeToGallery(imageFile, "$baseName.jpg", "image/jpeg", isVideo = false)
        val outVideoPath = writeToGallery(videoFile, "$baseName.mp4", "video/mp4", isVideo = true)

        return ExportResult(
            imagePath = outImagePath,
            videoPath = outVideoPath,
            motionPhotoPath = null
        )
    }

    /** 【需求 2 — 关闭】标准 Android MotionPhoto：视频嵌入图片内部。 */
    private fun exportStandardMotionPhoto(imageFile: File, videoFile: File): ExportResult {
        val outputDir = context.cacheDir
        val outputFile = File(outputDir, "MVIMG_${UUID.randomUUID()}_MP.jpg")

        MotionPhotoGeneratorHtml.generate(
            imagePath = imageFile.absolutePath,
            videoPath = videoFile.absolutePath,
            outputPath = outputFile.absolutePath
        )

        return ExportResult(
            imagePath = outputFile.absolutePath,
            videoPath = null,
            motionPhotoPath = outputFile.absolutePath
        )
    }

    /**
     * 把 [source] 登记进公共相册并返回可访问的本地路径。
     * API 29+ 走 MediaStore（无需存储权限）；旧版本写公共目录后触发 MediaScanner。
     */
    private fun writeToGallery(source: File, displayName: String, mimeType: String, isVideo: Boolean): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                // 华为图库在 DCIM/Camera 下对“同名 jpg+mp4”的配对识别最稳定
                put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_DIR)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(collection, values)
                ?: throw java.io.IOException("MediaStore insert failed for $displayName")
            try {
                context.contentResolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                } ?: throw java.io.IOException("openOutputStream failed for $displayName")

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                context.contentResolver.update(uri, values, null, null)

                return resolvePath(uri) ?: source.absolutePath
            } catch (e: Exception) {
                try {
                    context.contentResolver.delete(uri, null, null)
                } catch (_: Exception) {
                }
                throw e
            }
        }

        // API < 29：写公共 DCIM/Camera 目录并触发扫描
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            "Camera"
        )
        dir.mkdirs()
        val target = File(dir, displayName)
        source.copyTo(target, overwrite = true)
        MediaScannerConnection.scanFile(
            context,
            arrayOf(target.absolutePath),
            arrayOf(mimeType),
            null
        )
        return target.absolutePath
    }

    private fun resolvePath(uri: Uri): String? {
        return try {
            context.contentResolver
                .query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }
}
