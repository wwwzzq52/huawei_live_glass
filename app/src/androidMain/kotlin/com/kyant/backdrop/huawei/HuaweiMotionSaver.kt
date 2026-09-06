package com.kyant.backdrop.huawei

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.IOException

/**
 * 华为动态照片保存器（纯原生 Kotlin，无 Flutter 依赖）。
 *
 * 把已移植的 [MotionPhotoGeneratorHuawei] / [MotionPhotoGeneratorHtml] 与
 * Android MediaStore 相册写入串联起来：
 *
 *  - 华为成对模式：先注入华为微视频 XMP + 生成同名 MP4 侧挂文件，
 *    再把「同名 JPG + 同名 MP4」写入 DCIM/Camera，华为图库可识别播放；
 *  - 标准模式：生成视频内嵌 JPG 的 Motion Photo，写入 DCIM/Camera。
 */
class HuaweiMotionSaver(private val context: Context) {

    data class SaveResult(
        val imagePath: String,
        val videoPath: String?,
        val motionPhotoPath: String?
    )

    companion object {
        private const val RELATIVE_DIR = Environment.DIRECTORY_DCIM + "/" + "Camera"

        /**
         * 把 content:// Uri 拷贝到应用缓存目录，返回本地文件。
         */
        fun copyUriToCache(context: Context, uri: Uri, name: String): File {
            val out = File(context.cacheDir, name)
            context.contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            } ?: throw IOException("无法打开所选文件: $uri")
            return out
        }
    }

    /** 华为成对文件模式：JPG 注入 XMP + 同名 MP4，写入相册。 */
    fun generateAndSaveHuawei(imagePath: String, videoPath: String): SaveResult {
        MotionPhotoGeneratorHuawei.generateSidecar(imagePath, videoPath)

        val imageFile = File(imagePath)
        val sidecar = File(imageFile.parentFile, "${imageFile.nameWithoutExtension}.mp4")

        val baseName = "IMG_${System.currentTimeMillis()}"
        val outImage = saveToGallery(imageFile, "$baseName.jpg", "image/jpeg")
        val outVideo = saveToGallery(sidecar, "$baseName.mp4", "video/mp4")

        return SaveResult(
            imagePath = outImage,
            videoPath = outVideo,
            motionPhotoPath = null
        )
    }

    /** 标准 Android Motion Photo：视频内嵌 JPG，写入相册。 */
    fun generateAndSaveStandard(imagePath: String, videoPath: String): SaveResult {
        val outputFile = File(context.cacheDir, "MVIMG_${System.currentTimeMillis()}_MP.jpg")
        MotionPhotoGeneratorHtml.generate(
            imagePath = imagePath,
            videoPath = videoPath,
            outputPath = outputFile.absolutePath
        )
        val saved = saveToGallery(outputFile, outputFile.name, "image/jpeg")
        return SaveResult(
            imagePath = saved,
            videoPath = null,
            motionPhotoPath = saved
        )
    }

    /**
     * 把 [source] 登记进公共相册并返回本地路径。
     * API 29+ 走 MediaStore（无需存储权限）；旧版本写公共目录后触发 MediaScanner。
     */
    private fun saveToGallery(source: File, displayName: String, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (mimeType.startsWith("video")) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                // 华为图库在 DCIM/Camera 下对「同名 jpg+mp4」配对识别最稳定
                put(MediaStore.MediaColumns.RELATIVE_PATH, RELATIVE_DIR)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(collection, values)
                ?: throw IOException("MediaStore insert 失败: $displayName")
            try {
                context.contentResolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                } ?: throw IOException("openOutputStream 失败: $displayName")

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
