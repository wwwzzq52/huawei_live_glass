package com.cloudmind.flutter_live_motion

/**
 * XMP 最小化更新器
 * 完全按照 HTML 的 "尝试自动修正" 功能（第 262-278 行）
 * 只更新 3 个长度字段，其他一切保持不变
 */
class XmpMerger {
    
    companion object {
        
        /**
         * 合并 XMP：保留原图的结构，只更新长度字段
         * @param originalXmp 原图的 XMP（如果有）
         * @param videoLength 视频长度
         * @return 合并后的 XMP
         */
        fun mergeXmp(originalXmp: String?, videoLength: Int): String {
            if (originalXmp.isNullOrEmpty()) {
                // 原图没有 XMP，使用默认模板
                return generateDefaultXmp(videoLength)
            }
            
            // 原图有 XMP，只更新长度字段（完全按照 HTML 第 262-278 行）
            return updateLengthFieldsOnly(originalXmp, videoLength)
        }
        
        /**
         * 只更新长度字段
         * 完全按照 HTML 的 "尝试自动修正" 功能（第 262-278 行）
         */
        private fun updateLengthFieldsOnly(xmp: String, videoLength: Int): String {
            var updatedXmp = xmp
            
            // 1. 更新 OpCamera:VideoLength="..."
            // const regex = /OpCamera:VideoLength="(\d+)"/g;
            updatedXmp = updatedXmp.replace(
                Regex("""OpCamera:VideoLength="\d+""""),
                """OpCamera:VideoLength="$videoLength""""
            )
            
            // 2. 更新 GCamera:MicroVideoOffset="..."
            // const regex2 = /GCamera:MicroVideoOffset="(\d+)"/g;
            updatedXmp = updatedXmp.replace(
                Regex("""GCamera:MicroVideoOffset="\d+""""),
                """GCamera:MicroVideoOffset="$videoLength""""
            )
            
            // 3. 更新 Item:Semantic="MotionPhoto" 后面的 Item:Length="..."
            // const regex3 = /Item:Semantic="MotionPhoto"((.|\r|\n)*?)Item:Length="(\d+)"/g;
            updatedXmp = updatedXmp.replace(
                Regex("""(Item:Semantic="MotionPhoto"[\s\S]*?Item:Length=")(\d+)(")"""),
                "$1$videoLength$3"
            )
            
            return updatedXmp
        }
        
        /**
         * 生成默认 XMP 模板
         * 对应 HTML 第 216-255 行
         */
        private fun generateDefaultXmp(videoLength: Int): String {
            return """<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 5.1.0-jc003">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
        xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"
        xmlns:OpCamera="http://ns.oplus.com/photos/1.0/camera/"
        xmlns:MiCamera="http://ns.xiaomi.com/photos/1.0/camera/"
        xmlns:Container="http://ns.google.com/photos/1.0/container/"
        xmlns:Item="http://ns.google.com/photos/1.0/container/item/"
      GCamera:MotionPhoto="1"
      GCamera:MotionPhotoVersion="1"
      GCamera:MotionPhotoPresentationTimestampUs="0"
      OpCamera:MotionPhotoPrimaryPresentationTimestampUs="0"
      OpCamera:MotionPhotoOwner="oplus"
      OpCamera:OLivePhotoVersion="2"
      OpCamera:VideoLength="$videoLength"
      GCamera:MicroVideoVersion="1"
      GCamera:MicroVideo="1"
      GCamera:MicroVideoOffset="$videoLength"
      GCamera:MicroVideoPresentationTimestampUs="0"
      MiCamera:XMPMeta="&lt;?xml version='1.0' encoding='UTF-8' standalone='yes' ?&gt;">
      <Container:Directory>
        <rdf:Seq>
          <rdf:li rdf:parseType="Resource">
            <Container:Item
              Item:Mime="image/jpeg"
              Item:Semantic="Primary"
              Item:Length="0"
              Item:Padding="0"/>
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
    }
}

