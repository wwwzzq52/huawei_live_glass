package com.kyant.backdrop.huawei

import java.io.File

/**
 * ============================================================================
 * 华为动态照片（Huawei Dynamic Photo / 微视频）生成与识别。
 *
 * 华为图库的动态照片本质上是「处理后的 JPG + 同目录同名 MP4」的成对文件，
 * 同时在 JPG 中写入微视频 XMP 元数据（GCamera:MicroVideo / OpCamera:VideoLength /
 * MiCamera:VideoLength 等字段）。本类在开源项目 aiglance/flutter_live_motion
 * （MIT License）基础上新增，用于扩展华为动态照片支持。
 *
 * 注意：标准 Android MotionPhoto（视频嵌入 JPG 内部）由
 * [MotionPhotoGeneratorHtml] 继续负责，本类只处理华为侧挂格式。
 * ============================================================================
 */
class MotionPhotoGeneratorHuawei {

    companion object {

        private const val XMP_HEADER = "http://ns.adobe.com/xap/1.0/\u0000"

        // APP1 段标记（XMP）
        private val APP1_MARKER = byteArrayOf(0xFF.toByte(), 0xE1.toByte())

        /**
         * 生成华为动态照片：
         * 1. 复制处理后的 JPG 到 imagePath（外部已生成，这里只负责写入 XMP）；
         * 2. 将视频复制为与 JPG 同目录、同名的 .mp4；
         * 3. 在 JPG 中写入/替换微视频 XMP。
         *
         * @param imagePath 处理后的 JPG 绝对路径（会被原地修改为带华为 XMP 的版本）
         * @param videoPath 动态片段 MP4 绝对路径
         */
        fun generateSidecar(imagePath: String, videoPath: String) {
            val imageFile = File(imagePath)
            val videoFile = File(videoPath)

            if (!imageFile.exists() || !videoFile.exists()) {
                throw java.io.IOException("Input files do not exist")
            }

            val videoBytes = videoFile.readBytes()

            // 1. 同名 MP4 输出到 JPG 同目录
            val sidecarDir = imageFile.parentFile
                ?: throw java.io.IOException("Cannot resolve image parent directory")
            val baseName = imageFile.nameWithoutExtension
            val sidecar = File(sidecarDir, "$baseName.mp4")
            if (sidecar.absolutePath != videoFile.absolutePath) {
                sidecar.writeBytes(videoBytes)
            }

            // 2. 在 JPG 中写入微视频 XMP
            val original = imageFile.readBytes()
            val xmp = buildHuaweiXmp(videoBytes.size.toLong())
            val updated = injectOrReplaceXmp(original, xmp)
            imageFile.writeBytes(updated)
        }

        /**
         * 识别一张 JPG 是否为华为动态照片。
         * 满足任一条件即返回 true：
         *  - JPG 内部嵌有 MP4（单文件微视频）；
         *  - XMP 含微视频字段（MicroVideo / VideoLength / MotionPhoto）；
         *  - 同目录存在同名 / _LIVE / _live / _MOTION / _motion 的 .mp4 侧挂视频。
         */
        fun isHuaweiMotionPhoto(imagePath: String): Boolean {
            val imageFile = File(imagePath)
            if (!imageFile.exists()) return false

            val bytes = try {
                imageFile.readBytes()
            } catch (e: Exception) {
                return false
            }

            // 1. 内嵌 MP4
            if (bytes.indexOfBytes("ftyp".toByteArray(Charsets.US_ASCII)) >= 0 &&
                bytes.indexOfBytes("moov".toByteArray(Charsets.US_ASCII)) >= 0 &&
                bytes.indexOfBytes("mdat".toByteArray(Charsets.US_ASCII)) >= 0
            ) {
                return true
            }

            // 2. XMP 微视频字段
            val xmp = extractXmp(bytes)
            if (xmp != null &&
                (xmp.contains("MicroVideo") ||
                 xmp.contains("VideoLength") ||
                 xmp.contains("MotionPhoto"))
            ) {
                return true
            }

            // 3. 侧挂同名 MP4
            val dir = imageFile.parentFile ?: return false
            val base = imageFile.nameWithoutExtension
            val candidates = listOf(
                "$base.mp4",
                "${base}_LIVE.mp4",
                "${base}_live.mp4",
                "${base}_MOTION.mp4",
                "${base}_motion.mp4",
            )
            return candidates.any { name -> File(dir, name).exists() }
        }

        // ------------------------------------------------------------------
        // XMP 构建
        // ------------------------------------------------------------------
        private fun buildHuaweiXmp(videoLength: Long): String {
            return """<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Photo Watermark">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
        xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
        xmlns:OpCamera="http://ns.oplus.com/photos/1.0/camera/"
        xmlns:MiCamera="http://ns.xiaomi.com/photos/1.0/camera/"
        xmlns:HwCamera="http://ns.huawei.com/photos/1.0/camera/"
        xmlns:Container="http://ns.google.com/photos/1.0/container/"
        xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
      GCamera:MicroVideo="1"
      GCamera:MicroVideoVersion="1"
      GCamera:MicroVideoOffset="$videoLength"
      GCamera:MicroVideoPresentationTimestampUs="0"
      OpCamera:MotionPhoto="1"
      OpCamera:VideoLength="$videoLength"
      MiCamera:MotionPhoto="1"
      MiCamera:VideoLength="$videoLength"
      HwCamera:MotionPhoto="1"
      HwCamera:VideoLength="$videoLength">
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="image/jpeg"
              Item:Semantic="Primary"
              Item:Length="0"/>
          </rdf:li>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="video/mp4"
              Item:Semantic="MotionPhoto"
              Item:Length="$videoLength"/>
          </rdf:li>
        </rdf:Seq>
      </Container:Directory>
    </rdf:Description>
  </rdf:RDF>
</x:xmpmeta>"""
        }

        // ------------------------------------------------------------------
        // JPEG APP1(XMP) 注入/替换
        // ------------------------------------------------------------------
        private fun injectOrReplaceXmp(jpeg: ByteArray, xmp: String): ByteArray {
            val payload = (xmp + "\n").toByteArray(Charsets.UTF_8)
            val segment = buildXmpApp1Segment(payload)

            // 若已存在 XMP APP1 段，则替换该段（保持位置）
            val existing = findXmpApp1Range(jpeg)
            if (existing != null) {
                val (start, end) = existing
                val out = ByteArray(jpeg.size - (end - start) + segment.size)
                System.arraycopy(jpeg, 0, out, 0, start)
                System.arraycopy(segment, 0, out, start, segment.size)
                System.arraycopy(jpeg, end, out, start + segment.size, jpeg.size - end)
                return out
            }

            // 不存在则插在 SOI（0xFFD8）之后
            if (jpeg.size >= 2 && jpeg[0] == 0xFF.toByte() && jpeg[1] == 0xD8.toByte()) {
                val out = ByteArray(jpeg.size + segment.size)
                System.arraycopy(jpeg, 0, out, 0, 2)
                System.arraycopy(segment, 0, out, 2, segment.size)
                System.arraycopy(jpeg, 2, out, 2 + segment.size, jpeg.size - 2)
                return out
            }

            // 非标准 JPEG，兜底：段 + 原图
            val out = ByteArray(segment.size + jpeg.size)
            System.arraycopy(segment, 0, out, 0, segment.size)
            System.arraycopy(jpeg, 0, out, segment.size, jpeg.size)
            return out
        }

        private fun buildXmpApp1Segment(payload: ByteArray): ByteArray {
            val header = XMP_HEADER.toByteArray(Charsets.UTF_8)
            // 长度 = 头 + 载荷 + 2（长度字段本身）
            val length = header.size + payload.size + 2
            val segment = ByteArray(length + 2)
            segment[0] = APP1_MARKER[0]
            segment[1] = APP1_MARKER[1]
            segment[2] = ((length shr 8) and 0xFF).toByte()
            segment[3] = (length and 0xFF).toByte()
            System.arraycopy(header, 0, segment, 4, header.size)
            System.arraycopy(payload, 0, segment, 4 + header.size, payload.size)
            return segment
        }

        /**
         * 定位 JPG 中已存在的 XMP APP1 段，返回 [start, end)（不含段长度字节头）。
         */
        private fun findXmpApp1Range(jpeg: ByteArray): Pair<Int, Int>? {
            var i = 0
            while (i + 4 <= jpeg.size) {
                if (jpeg[i] == 0xFF.toByte() && jpeg[i + 1] == 0xE1.toByte()) {
                    val len = ((jpeg[i + 2].toInt() and 0xFF) shl 8) or
                              (jpeg[i + 3].toInt() and 0xFF)
                    if (len >= 2 && i + 2 + len <= jpeg.size) {
                        val headerStart = i + 4
                        val headerEnd = minOf(headerStart + XMP_HEADER.length, jpeg.size)
                        val header = String(
                            jpeg, headerStart, headerEnd - headerStart, Charsets.UTF_8
                        )
                        if (header == XMP_HEADER) {
                            return Pair(i, i + 2 + len)
                        }
                    }
                }
                i++
            }
            return null
        }

        private fun extractXmp(jpeg: ByteArray): String? {
            val startMarker = "<x:xmpmeta".toByteArray(Charsets.UTF_8)
            val endMarker = "</x:xmpmeta>".toByteArray(Charsets.UTF_8)
            val s = jpeg.indexOfBytes(startMarker)
            if (s < 0) return null
            val e = jpeg.indexOfBytes(endMarker, s)
            if (e < 0) return null
            return String(jpeg, s, e + endMarker.size - s, Charsets.UTF_8)
        }

        private fun ByteArray.indexOfBytes(target: ByteArray, from: Int = 0): Int {
            if (target.isEmpty() || size < target.size) return -1
            val first = target[0]
            var i = from
            while (i <= size - target.size) {
                if (this[i] == first) {
                    var match = true
                    for (j in target.indices) {
                        if (this[i + j] != target[j]) {
                            match = false
                            break
                        }
                    }
                    if (match) return i
                }
                i++
            }
            return -1
        }
    }
}
