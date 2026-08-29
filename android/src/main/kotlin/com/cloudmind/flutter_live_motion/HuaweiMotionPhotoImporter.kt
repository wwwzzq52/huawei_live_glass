package com.cloudmind.flutter_live_motion

import android.content.Context
import java.io.File
import java.util.UUID

/**
 * 【华为动态照片 · 单文件解析器】
 *
 * 华为动态照片是「单文件 .jpg」：JPEG 图像段（截止 FFD9）+ 内嵌 MP4 + 40 字节尾标记。
 * 本类负责从选中的华为动态照片里**提取内嵌的视频片段**，落盘到应用缓存。
 *
 * 内嵌 MP4 的定位规则（与华为相机生成文件一致）：
 *   1. 找到 JPEG EOI（FF D9），其后通常跟一串 0x00 填充；
 *   2. 跳过填充后是 MP4 box：`ctrace`（华为扩展 box）或直接 `ftyp`；
 *   3. 真正的 MP4 视频从 box 头（size 4 字节 + type 4 字节）开始；
 *   4. 文件最后 40 字节是华为尾标记，不属于视频，需要剔除。
 */
object HuaweiMotionPhotoImporter {

    private val JPEG_EOI = byteArrayOf(0xFF.toByte(), 0xD9.toByte())
    private val BOX_FTYP = "ftyp".toByteArray(Charsets.US_ASCII)
    private val BOX_CTRACE = "ctrace".toByteArray(Charsets.US_ASCII)

    /**
     * 从华为动态照片中提取内嵌视频。
     * @return 提取出的 MP4 缓存路径；不是华为动态照片时返回 null。
     */
    fun extractVideo(context: Context, imagePath: String): String? {
        return try {
            val file = File(imagePath)
            if (!file.exists() || !file.isFile) return null
            val bytes = file.readBytes()

            val eoi = findJpegEoi(bytes) ?: return null

            // 定位 MP4 起始：跳过 JPEG EOI 后的零填充，随后应是 box 头
            var cursor = eoi + 2
            while (cursor < bytes.size && bytes[cursor] == 0.toByte()) cursor++

            val videoStart = if (looksLikeBoxHeader(bytes, cursor)) {
                cursor
            } else if (looksLikeBoxHeader(bytes, cursor - 4) && cursor >= 4) {
                cursor - 4
            } else {
                // 兜底：在 EOI 之后直接搜索 ftyp
                val ftyp = indexOf(bytes, BOX_FTYP, eoi)
                if (ftyp < 0) return null else ftyp - 4
            }

            if (videoStart <= eoi || videoStart + 8 > bytes.size) return null

            // 剔除 40 字节华为尾标记（最后 20 字节以 "LIVE_" 开头）
            val n = bytes.size
            var videoEnd = n
            if (n >= 40) {
                val livePos = indexOf(bytes, "LIVE_".toByteArray(Charsets.US_ASCII), n - 20)
                if (livePos == n - 20) videoEnd = n - 40
            }

            if (videoEnd <= videoStart) return null

            val out = File(context.cacheDir, "extracted_${UUID.randomUUID()}.mp4")
            out.writeBytes(bytes.copyOfRange(videoStart, videoEnd))
            out.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    /** 查找 JPEG EOI：FFD9 之后是零填充 + MP4 box 头。 */
    private fun findJpegEoi(bytes: ByteArray): Int? {
        var i = 0
        while (i < bytes.size - 1) {
            if (bytes[i] == JPEG_EOI[0] && bytes[i + 1] == JPEG_EOI[1]) {
                var j = i + 2
                while (j < bytes.size && bytes[j] == 0.toByte()) j++
                if (looksLikeBoxHeader(bytes, j)) return i
            }
            i++
        }
        // 兜底：找不到 box 头时返回第一个 FFD9
        return indexOf(bytes, JPEG_EOI, 0).takeIf { it >= 0 }
    }

    /** 判断 [pos] 处是否为合法的 MP4 box 头（4 字节 size + 4 字节 type）。 */
    private fun looksLikeBoxHeader(bytes: ByteArray, pos: Int): Boolean {
        if (pos < 0 || pos + 8 > bytes.size) return false
        val size = (((bytes[pos].toInt() and 0xFF) shl 24) or
                ((bytes[pos + 1].toInt() and 0xFF) shl 16) or
                ((bytes[pos + 2].toInt() and 0xFF) shl 8) or
                (bytes[pos + 3].toInt() and 0xFF))
        if (size <= 8 || size > 512 * 1024 * 1024) return false
        val type = String(bytes, pos + 4, 4, Charsets.US_ASCII)
        return type == "ctrace" || type == "ftyp"
    }

    private fun indexOf(data: ByteArray, pattern: ByteArray, startFrom: Int = 0): Int {
        if (pattern.isEmpty() || data.size < pattern.size) return -1
        var start = startFrom.coerceAtLeast(0)
        outer@ while (start <= data.size - pattern.size) {
            for (j in pattern.indices) {
                if (data[start + j] != pattern[j]) {
                    start++
                    continue@outer
                }
            }
            return start
        }
        return -1
    }
}
