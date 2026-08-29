package com.cloudmind.flutter_live_motion

import java.io.*

/**
 * 完全按照 HTML 实现的 Motion Photo 生成器
 * 参考: /example/lib/edit.html
 * 真正的 1:1 移植，包含所有细节
 */
class MotionPhotoGeneratorHtml {

    companion object {
        
        fun generate(imagePath: String, videoPath: String, outputPath: String) {
            val videoFile = File(videoPath)
            val imageFile = File(imagePath)

            if (!videoFile.exists() || !imageFile.exists()) {
                throw IOException("Input files do not exist")
            }

            // 读取视频和图片
            val newVideoArray = videoFile.readBytes()
            val originalArray = imageFile.readBytes()
            
            // 提取原图的 XMP（如果有）
            val originalXmp = extractOriginalXmp(originalArray)
            
            // 智能合并 XMP：保留原图的结构（如 GainMap），只更新 Motion Photo 字段
            val xmpEditorContent = XmpMerger.mergeXmp(originalXmp, newVideoArray.size)
            
            // 查找现有 XMP（对应 HTML 第 345-351 行）
            val xmpStartMarker = "<x:xmpmeta".toByteArray(Charsets.UTF_8)
            val xmpEndMarker = "</x:xmpmeta>".toByteArray(Charsets.UTF_8)
            
            var xmpStart: Int
            var xmpEnd: Int
            var hasXMP = false
            var updatedXmpArray: ByteArray
            
            val xmpStartIndex = indexOfSubarray(originalArray, xmpStartMarker)
            if (xmpStartIndex != -1) {
                val xmpEndIndex = indexOfSubarray(originalArray, xmpEndMarker, xmpStartIndex)
                if (xmpEndIndex != -1) {
                    xmpStart = xmpStartIndex
                    xmpEnd = xmpEndIndex + 12
                    hasXMP = true
                } else {
                    xmpStart = 2
                    xmpEnd = 2
                    hasXMP = false
                }
            } else {
                xmpStart = 2
                xmpEnd = 2
                hasXMP = false
            }
            
            // 生成 XMP 数组（对应 HTML 第 344-355 行）
            updatedXmpArray = if (hasXMP) {
                xmpEditorContent.toByteArray(Charsets.UTF_8)
            } else {
                // 原图片不包含XMP，需构建完整的APP1字段
                embedXMP(xmpEditorContent)
            }
            
            // 查找视频起始位置（对应 HTML 第 356-366 行）
            val ftypMarker = "ftyp".toByteArray(Charsets.UTF_8)
            var videoStart = indexOfSubarray(originalArray, ftypMarker)
            if (videoStart != -1) {
                videoStart -= 4
            } else {
                videoStart = originalArray.size
            }
            
            // 计算新文件大小（对应 HTML 第 370 行）
            val updatedFileArray = ByteArray(
                videoStart + newVideoArray.size - xmpEnd + xmpStart + updatedXmpArray.size
            )
            
            // 复制 SOI 到 XMP 开始的部分（对应 HTML 第 371-383 行）
            var rawApp1 = originalArray.copyOfRange(0, xmpStart)
            
            // 修正包含XMP的APP1字段头部长度标识（对应 HTML 第 372-383 行）
            val searchPattern = byteArrayOf(0xFF.toByte(), 0xE1.toByte())
            val app1Start = findPatternReverse(rawApp1, searchPattern)
            
            if (app1Start != -1) {
                val originalLength = ((rawApp1[app1Start + 2].toInt() and 0xFF) shl 8) or 
                                    (rawApp1[app1Start + 3].toInt() and 0xFF)
                val n = updatedXmpArray.size - (xmpEnd - xmpStart)
                val newLength = originalLength + n
                rawApp1[app1Start + 2] = ((newLength shr 8) and 0xFF).toByte()
                rawApp1[app1Start + 3] = (newLength and 0xFF).toByte()
            }
            
            // 组装新文件（对应 HTML 第 384-402 行）
            System.arraycopy(rawApp1, 0, updatedFileArray, 0, rawApp1.size)
            System.arraycopy(updatedXmpArray, 0, updatedFileArray, xmpStart, updatedXmpArray.size)
            System.arraycopy(
                originalArray, xmpEnd, 
                updatedFileArray, xmpStart + updatedXmpArray.size, 
                videoStart - xmpEnd
            )
            System.arraycopy(
                newVideoArray, 0, 
                updatedFileArray, videoStart - xmpEnd + xmpStart + updatedXmpArray.size, 
                newVideoArray.size
            )
            
            // 写入输出文件
            File(outputPath).writeBytes(updatedFileArray)
        }
        
        /**
         * 提取原图的 XMP
         */
        private fun extractOriginalXmp(imageArray: ByteArray): String? {
            val xmpStartMarker = "<x:xmpmeta".toByteArray(Charsets.UTF_8)
            val xmpEndMarker = "</x:xmpmeta>".toByteArray(Charsets.UTF_8)
            
            val xmpStart = indexOfSubarray(imageArray, xmpStartMarker)
            if (xmpStart == -1) return null
            
            val xmpEnd = indexOfSubarray(imageArray, xmpEndMarker, xmpStart)
            if (xmpEnd == -1) return null
            
            val xmpBytes = imageArray.copyOfRange(xmpStart, xmpEnd + 12)
            return String(xmpBytes, Charsets.UTF_8)
        }
        
        /**
         * 嵌入 XMP
         * 完全按照 HTML 第 303-320 行
         */
        private fun embedXMP(xmpData: String): ByteArray {
            // xmpPayload = xmpData + '\x0A'
            val xmpPayload = (xmpData + "\n").toByteArray(Charsets.UTF_8)
            
            // xmpHeader = 'http://ns.adobe.com/xap/1.0/\x00'
            val xmpHeader = "http://ns.adobe.com/xap/1.0/\u0000".toByteArray(Charsets.UTF_8)
            
            // xmpLength = xmpPayload.length + xmpHeader.length + 2
            val xmpLength = xmpPayload.size + xmpHeader.size + 2
            
            // xmpSegment
            val xmpSegment = ByteArray(xmpLength + 2)
            
            // xmpMarker = [0xFF, 0xE1]
            xmpSegment[0] = 0xFF.toByte()
            xmpSegment[1] = 0xE1.toByte()
            
            // length bytes
            xmpSegment[2] = ((xmpLength shr 8) and 0xFF).toByte()
            xmpSegment[3] = (xmpLength and 0xFF).toByte()
            
            // xmpHeader
            System.arraycopy(xmpHeader, 0, xmpSegment, 4, xmpHeader.size)
            
            // xmpPayload
            System.arraycopy(xmpPayload, 0, xmpSegment, 4 + xmpHeader.size, xmpPayload.size)
            
            return xmpSegment
        }
        
        /**
         * 查找子数组
         * 对应 HTML 的 indexOfSubarrayOptimized（第 137-153 行）
         */
        private fun indexOfSubarray(array: ByteArray, subarray: ByteArray, startFrom: Int = 0): Int {
            if (subarray.isEmpty() || array.size < subarray.size) return -1
            
            val firstByte = subarray[0]
            var startIndex = startFrom
            
            while (startIndex <= array.size - subarray.size) {
                // 查找第一个字节
                var found = false
                for (i in startIndex until array.size - subarray.size + 1) {
                    if (array[i] == firstByte) {
                        startIndex = i
                        found = true
                        break
                    }
                }
                
                if (!found) return -1
                
                // 检查完整匹配
                var match = true
                for (j in subarray.indices) {
                    if (array[startIndex + j] != subarray[j]) {
                        match = false
                        break
                    }
                }
                
                if (match) return startIndex
                startIndex++
            }
            
            return -1
        }
        
        /**
         * 反向查找子数组
         * 对应 HTML 的 findPatternInUint8ArrayReverse（第 154-171 行）
         */
        private fun findPatternReverse(array: ByteArray, pattern: ByteArray): Int {
            val patternLength = pattern.size
            val arrayLength = array.size
            
            for (i in arrayLength - patternLength downTo 0) {
                var match = true
                for (j in pattern.indices) {
                    if (array[i + j] != pattern[j]) {
                        match = false
                        break
                    }
                }
                if (match) {
                    return i
                }
            }
            return -1
        }
    }
}

