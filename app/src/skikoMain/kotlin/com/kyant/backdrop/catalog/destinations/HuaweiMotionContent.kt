package com.kyant.backdrop.catalog.destinations

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 桌面（skiko）端占位实现：华为动态照片依赖 Android MediaStore 与相册，
 * 桌面端不提供。
 */
@Composable
actual fun HuaweiMotionContent() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BasicText(
                "Huawei Motion Photo",
                style = TextStyle(Color.White, 22f.sp)
            )
            BasicText(
                "This feature is only available on Android.",
                Modifier.padding(top = 12f.dp),
                style = TextStyle(Color(0xFFAAAAAA), 14f.sp)
            )
        }
    }
}
