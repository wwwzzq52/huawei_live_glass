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
 * 【华为动态照片 · 单文件导出器】
 *
 * 华为图库识别动态照片的规则（本 App 采用）：
 *   一个 JPEG 文件，内部结构为：
 *     [完整 JPEG 图像段，截止到最后一个 FFD9]
 *     + [MP4 动态片段原始字节]
 *     + [40 字节华为尾标记]
 *
 * 其中 40 字节尾标记为固定格式（与华为相机生成文件一致）：
 *     "922:503 " + 12 个空格          （20 字节）
 *     "LIVE_"    + 7 位随机数字 + 8 个空格（20 字节）
 *
 * 这样导出后就是一个 .jpg 单文件，华为图库会直接识别为“动态照片”并播放内嵌视频，
 * 不再需要“同目录同名 mp4”双文件关联。
 *
 * 导出模式：
 *   - "huawei"（默认，兼容旧值 "huaweiPair"/"auto"）：单文件华为动态照片；
 *   - "standard"：标准 Android MotionPhoto（XMP 声明 + 视频嵌入 JPEG 尾部）。
 */
class HuaweiMotionPhotoExporter private constructor(
    private val context: Context
) {

    /** 导出结果。单文件模式下 imagePath == motionPhotoPath，videoPath 恒为 null。 */
    data class ExportResult(
        val imagePath: String,
        val videoPath: String?,
        val motionPhotoPath: String?
    )

    companion object {

        private val RELATIVE_DIR =
            Environment.DIRECTORY_DCIM + File.separator + "Camera"

        private val JPEG_EOI = byteArrayOf(0xFF.toByte(), 0xD9.toByte())

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

        // 默认一律输出华为单文件动态照片（旧值 huaweiPair / auto 兼容为 huawei）
        val resolvedMode = if (mode == "standard") "standard" else "huawei"

        return if (resolvedMode == "standard") {
            exportStandardMotionPhoto(imageFile, videoFile)
        } else {
            exportHuaweiSingleFile(imageFile, videoFile)
        }
    }

    /** 华为动态照片：JPEG(截断到 EOI) + MP4 + 40 字节尾标记，合成单个 .jpg。 */
    private fun exportHuaweiSingleFile(imageFile: File, videoFile: File): ExportResult {
        val imageBytes = imageFile.readBytes()
        val eoi = lastIndexOf(imageBytes, JPEG_EOI)
        if (eoi < 0) {
            throw java.io.IOException("Not a valid JPEG file (missing FFD9 marker)")
        }
        val jpegEnd = eoi + 2

        val videoBytes = videoFile.readBytes()
        val trailer = buildHuaweiTrailer()

        val merged = ByteArray(jpegEnd + videoBytes.size + trailer.size)
        System.arraycopy(imageBytes, 0, merged, 0, jpegEnd)
        System.arraycopy(videoBytes, 0, merged, jpegEnd, videoBytes.size)
        System.arraycopy(trailer, 0, merged, jpegEnd + videoBytes.size, trailer.size)

        // 先落盘缓存，再登记进公共相册（DCIM/Camera），保证华为图库立即发现
        val tmp = File(context.cacheDir, "IMG_${System.currentTimeMillis()}.jpg")
        tmp.writeBytes(merged)

        val displayName = "IMG_${System.currentTimeMillis()}.jpg"
        val outPath = writeToGallery(tmp, displayName, "image/jpeg", isVideo = false)

        return ExportResult(
            imagePath = outPath,
            videoPath = null,
            motionPhotoPath = outPath
        )
    }

    /** 标准 Android MotionPhoto：XMP 声明 + 视频嵌入 JPEG 内部。 */
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

    /** 构造 40 字节华为尾标记。 */
    private fun buildHuaweiTrailer(): ByteArray {
        val digits = java.util.Random().nextInt(10_000_000).toString().padStart(7, '0')
        val marker = "922:503 " + " ".repeat(12) + "LIVE_" + digits + " ".repeat(8)
        return marker.toByteArray(Charsets.US_ASCII)
    }

    /** 从尾部向前查找 [pattern]，返回首次命中偏移，未找到返回 -1。 */
    private fun lastIndexOf(data: ByteArray, pattern: ByteArray): Int {
        if (pattern.isEmpty() || data.size < pattern.size) return -1
        outer@ for (i in data.size - pattern.size downTo 0) {
            for (j in pattern.indices) {
                if (data[i + j] != pattern[j]) continue@outer
            }
            return i
        }
        return -1
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
                ?: copyUriToCache(uri)
        } catch (_: Exception) {
            copyUriToCache(uri)
        }
    }

    /** 现代 Android 下 DATA 列常为 null，此时把相册内容拷回缓存以拿到可读路径。 */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val out = File(context.cacheDir, "gallery_${UUID.randomUUID()}.jpg")
            context.contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it) }
            }
            out.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
