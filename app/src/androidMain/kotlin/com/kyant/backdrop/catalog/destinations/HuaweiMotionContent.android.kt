package com.kyant.backdrop.catalog.destinations

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kyant.backdrop.catalog.BackdropDemoScaffold
import com.kyant.backdrop.catalog.components.LiquidButton
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.effects.vibrancy
import com.kyant.backdrop.highlight.Highlight
import com.kyant.backdrop.huawei.HuaweiMotionSaver
import com.kyant.backdrop.huawei.MotionPhotoGeneratorHuawei
import com.kyant.shapes.RoundedRectangle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Android 端华为动态照片功能页。
 *
 * 流程：选择 JPG →（可选）选择 MP4 → 自动识别是否为华为动态照片 →
 * 选择保存模式（华为成对 / 标准内嵌）→ 写入系统相册。
 */
@Composable
actual fun HuaweiMotionContent() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var imagePath by remember { mutableStateOf<String?>(null) }
    var imagePainter by remember { mutableStateOf<Painter?>(null) }
    var videoPath by remember { mutableStateOf<String?>(null) }
    var isHuawei by remember { mutableStateOf<Boolean?>(null) }
    var huaweiMode by remember { mutableStateOf(true) }
    var status by remember { mutableStateOf("") }

    val pickImage = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            try {
                val file = HuaweiMotionSaver.copyUriToCache(context, uri, "motion_input.jpg")
                imagePath = file.absolutePath
                imagePainter = rememberPainterFromFile(file)
                videoPath = null
                isHuawei = null
                status = "已选择图片：${file.name}"
            } catch (e: Exception) {
                status = "读取图片失败：${e.message}"
            }
        }
    }

    val pickVideo = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            try {
                val file = HuaweiMotionSaver.copyUriToCache(context, uri, "motion_input.mp4")
                videoPath = file.absolutePath
                status = "已选择视频：${file.name}"
            } catch (e: Exception) {
                status = "读取视频失败：${e.message}"
            }
        }
    }

    fun detectHuawei() {
        val img = imagePath ?: return
        scope.launch {
            status = "识别中…"
            val result = withContext(Dispatchers.IO) {
                runCatching { MotionPhotoGeneratorHuawei.isHuaweiMotionPhoto(img) }.getOrDefault(false)
            }
            isHuawei = result
            status = if (result) "✅ 识别为华为动态照片" else "❌ 未识别为华为动态照片"
        }
    }

    fun doSave() {
        val img = imagePath ?: run { status = "请先选择图片"; return }
        val vid = videoPath ?: run { status = "请先选择视频"; return }
        scope.launch {
            status = "保存中…"
            val result = runCatching {
                withContext(Dispatchers.IO) {
                    val saver = HuaweiMotionSaver(context)
                    if (huaweiMode) {
                        saver.generateAndSaveHuawei(img, vid)
                    } else {
                        saver.generateAndSaveStandard(img, vid)
                    }
                }
            }
            status = result.fold(
                onSuccess = { "✅ 已保存到相册" },
                onFailure = { "保存失败：${it.message}" }
            )
        }
    }

    BackdropDemoScaffold { backdrop ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(16f.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14f.dp)
        ) {
            BasicText(
                "华为动态照片 · 液态玻璃",
                Modifier.padding(top = 12f.dp),
                style = TextStyle(Color.White, 22f.sp, FontWeight.Medium)
            )

            // 图片预览卡片
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(260f.dp)
                    .drawBackdrop(
                        backdrop = backdrop,
                        shape = { RoundedRectangle(28f.dp) },
                        effects = {
                            vibrancy()
                            blur(4f.dp.toPx())
                            lens(16f.dp.toPx(), 32f.dp.toPx())
                        },
                        highlight = { Highlight.Plain },
                        onDrawSurface = { drawRect(Color.Black.copy(alpha = 0.35f)) }
                    ),
                contentAlignment = Alignment.Center
            ) {
                val painter = imagePainter
                if (painter != null) {
                    Image(
                        painter = painter,
                        null,
                        Modifier.fillMaxSize(),
                        contentScale = ContentScale.Fit
                    )
                } else {
                    BasicText("未选择图片", style = TextStyle(Color(0xFFAAAAAA), 15f.sp))
                }
            }

            // 状态 / 识别结果
            BasicText(
                when {
                    status.isNotBlank() -> status
                    isHuawei == true -> "✅ 华为动态照片"
                    isHuawei == false -> "❌ 非华为动态照片"
                    else -> "请选择图片和视频"
                },
                style = TextStyle(if (status.contains("✅")) Color(0xFF6FD26F) else Color.White, 14f.sp)
            )

            // 操作按钮
            LiquidButton(
                {
                    pickImage.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                },
                backdrop,
                Modifier.fillMaxWidth(),
                tint = Color(0xFF0088FF)
            ) {
                BasicText("选择图片 (JPG)", style = TextStyle(Color.White, 16f.sp))
            }

            LiquidButton(
                {
                    pickVideo.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
                    )
                },
                backdrop,
                Modifier.fillMaxWidth(),
                tint = Color(0xFFFF8D28)
            ) {
                BasicText("选择视频 (MP4)", style = TextStyle(Color.White, 16f.sp))
            }

            LiquidButton(
                { detectHuawei() },
                backdrop,
                Modifier.fillMaxWidth(),
                tint = Color(0xFF7C4DFF)
            ) {
                BasicText("识别华为动态照片", style = TextStyle(Color.White, 16f.sp))
            }

            // 模式切换
            LiquidButton(
                { huaweiMode = !huaweiMode },
                backdrop,
                Modifier.fillMaxWidth(),
                tint = if (huaweiMode) Color(0xFF00BFA5) else Color(0xFF607D8B)
            ) {
                BasicText(
                    "导出模式：${if (huaweiMode) "华为成对文件" else "标准内嵌"}",
                    style = TextStyle(Color.White, 16f.sp)
                )
            }

            LiquidButton(
                { doSave() },
                backdrop,
                Modifier.fillMaxWidth(),
                tint = Color(0xFFE53935)
            ) {
                BasicText("保存到相册", style = TextStyle(Color.White, 17f.sp, FontWeight.Medium))
            }

            BasicText(
                "说明：华为模式输出「同名 JPG + MP4」并写入微视频 XMP；\n标准模式输出视频内嵌的 Motion Photo。",
                Modifier.padding(top = 4f.dp, bottom = 16f.dp),
                style = TextStyle(Color(0xFF888888), 12f.sp)
            )
        }
    }
}

@Composable
private fun rememberPainterFromFile(file: java.io.File): Painter? {
    return remember(file) {
        runCatching {
            android.graphics.BitmapFactory
                .decodeFile(file.absolutePath)
                ?.asImageBitmap()
                ?.let { BitmapPainter(it) }
        }.getOrNull()
    }
}
