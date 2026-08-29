package com.cloudmind.flutter_live_motion.xmp

class GoogleXmpGenerator : XmpGenerator {
    
    // Standard Google Motion Photo v2 (Container) format
    // Used by Pixel (modern), Samsung (OneUI 2.5+), and generic Android
    private val TEMPLATE = "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\" x:xmptk=\"Adobe XMP Core 5.1.0-jc003\">" +
            "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">" +
            "<rdf:Description rdf:about=\"\" " +
            "xmlns:GCamera=\"http://ns.google.com/photos/1.0/camera/\" " +
            "xmlns:Container=\"http://ns.google.com/photos/1.0/container/\" " +
            "xmlns:Item=\"http://ns.google.com/photos/1.0/container/item/\" " +
            "GCamera:MotionPhoto=\"1\" " +
            "GCamera:MotionPhotoVersion=\"1\" " +
            "GCamera:MotionPhotoPresentationTimestampUs=\"0\">" +
            "<Container:Directory>" +
            "<rdf:Seq>" +
            "<rdf:li rdf:parseType=\"Resource\">" +
            "<Container:Item " +
            "Item:Mime=\"image/jpeg\" " +
            "Item:Semantic=\"Primary\"/>" +
            "</rdf:li>" +
            "<rdf:li rdf:parseType=\"Resource\">" +
            "<Container:Item " +
            "Item:Mime=\"video/mp4\" " +
            "Item:Semantic=\"MotionPhoto\" " +
            "Item:Length=\"%d\"/>" +
            "</rdf:li>" +
            "</rdf:Seq>" +
            "</Container:Directory>" +
            "</rdf:Description>" +
            "</rdf:RDF>" +
            "%s" + // Padding
            "</x:xmpmeta>"

    override fun generateXmp(videoLength: Long): String {
        return String.format(TEMPLATE, videoLength, XmpPadding.PADDING)
    }
}
