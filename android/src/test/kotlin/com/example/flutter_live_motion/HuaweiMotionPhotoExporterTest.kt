package com.cloudmind.flutter_live_motion

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * 【新增测试】华为配对识别逻辑的单元测试（不依赖 Android 环境）。
 * 仅验证同名/扩展名判定函数。
 */
class HuaweiMotionPhotoExporterTest {

    @Test
    fun detectsSameBaseNamePair() {
        assertTrue(isHuaweiPairName("IMG_20260808_133148.jpg", "IMG_20260808_133148.mp4"))
    }

    @Test
    fun detectsJpegExtension() {
        assertTrue(isHuaweiPairName("IMG_20260808_133148.jpeg", "IMG_20260808_133148.mp4"))
    }

    @Test
    fun rejectsDifferentBaseName() {
        assertFalse(isHuaweiPairName("IMG_20260808_133148.jpg", "IMG_20260808_133149.mp4"))
    }

    @Test
    fun rejectsNonMp4Video() {
        assertFalse(isHuaweiPairName("IMG_20260808_133148.jpg", "IMG_20260808_133148.mov"))
    }

    @Test
    fun rejectsNonJpgImage() {
        assertFalse(isHuaweiPairName("IMG_20260808_133148.png", "IMG_20260808_133148.mp4"))
    }

    companion object {
        fun isHuaweiPairName(imagePath: String, videoPath: String): Boolean {
            val imageFile = java.io.File(imagePath)
            val videoFile = java.io.File(videoPath)
            return imageFile.nameWithoutExtension.equals(videoFile.nameWithoutExtension, ignoreCase = true) &&
                    (imageFile.extension.equals("jpg", ignoreCase = true) ||
                            imageFile.extension.equals("jpeg", ignoreCase = true)) &&
                    videoFile.extension.equals("mp4", ignoreCase = true)
        }
    }
}
