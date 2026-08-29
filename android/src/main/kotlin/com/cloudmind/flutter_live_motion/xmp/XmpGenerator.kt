package com.cloudmind.flutter_live_motion.xmp

interface XmpGenerator {
    /**
     * Generates the XMP metadata packet for a Motion Photo.
     * @param videoLength The length of the video file in bytes.
     * @return The complete XMP packet string.
     */
    fun generateXmp(videoLength: Long): String
}
