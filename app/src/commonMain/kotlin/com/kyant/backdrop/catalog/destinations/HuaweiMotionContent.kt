package com.kyant.backdrop.catalog.destinations

import androidx.compose.runtime.Composable

/**
 * 华为动态照片 · 识别与保存功能页。
 *
 * 该页面把「液态玻璃」视觉（本仓库 backdrop 库）与「华为动态照片」能力
 * （app/src/androidMain/kotlin/com/kyant/backdrop/huawei/ 下的移植类）结合：
 *   - 选择 JPG + MP4；
 *   - 识别该 JPG 是否为华为动态照片（内嵌 MP4 / XMP 微视频字段 / 同名侧挂 MP4）；
 *   - 生成并保存到系统相册（华为成对文件模式 / 标准视频内嵌模式）。
 *
 * 各平台通过 expect/actual 提供实现；仅 Android 端具备真实能力，
 * 桌面（skiko）端提供占位说明。
 */
@Composable
expect fun HuaweiMotionContent()
