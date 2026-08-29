// =============================================================================
// Liquid Glass refraction shader for Flutter (runtime effect / AGSL-compatible)
// -----------------------------------------------------------------------------
// Ported from Kyant0/AndroidLiquidGlass
//   RoundedRectRefractionWithDispersionShaderString
//   (backdrop/src/commonMain/kotlin/com/kyant/backdrop/internal/Shaders.kt)
// Licensed under the Apache License, Version 2.0.
//
// Differences from the original AGSL:
//   - AGSL `uniform shader content`  ->  `uniform sampler2D uContent`
//   - AGSL `content.eval(coord)`     ->  `texture(uContent, coverUv(...))`
//   - `half4 main(float2 coord)`     ->  `layout(location=0) out vec4 fragColor`
// =============================================================================
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform sampler2D uContent;
uniform vec2 uSize;         // 输出画布尺寸（逻辑像素）
uniform vec2 uContentSize;  // 背景图片像素尺寸
uniform vec4 uCornerRadii;  // 四角圆角半径（逻辑像素）
uniform float uRefractionHeight;
uniform float uRefractionAmount;
uniform float uDepthEffect;
uniform float uChromaticAberration;

layout(location = 0) out vec4 fragColor;

float radiusAt(vec2 coord, vec4 radii) {
    if (coord.x >= 0.0) {
        if (coord.y <= 0.0) return radii.y;
        else return radii.z;
    } else {
        if (coord.y <= 0.0) return radii.x;
        else return radii.w;
    }
}

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, 0.0)) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, 0.0));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

float circleMap(float x) {
    return 1.0 - sqrt(1.0 - x * x);
}

// 把输出像素坐标按 BoxFit.cover 映射到内容图 UV，避免拉伸变形
vec2 coverUv(vec2 coord, vec2 size, vec2 contentSize) {
    float scale = max(size.x / contentSize.x, size.y / contentSize.y);
    vec2 scaled = contentSize * scale;
    vec2 offset = (scaled - size) * 0.5;
    vec2 src = coord + offset;
    return src / scaled;
}

void main() {
    vec2 coord = FlutterFragCoord().xy;

    vec2 halfSize = uSize * 0.5;
    vec2 centeredCoord = coord - halfSize;
    float radius = radiusAt(coord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);
    if (-sd >= uRefractionHeight) {
        fragColor = texture(uContent, coverUv(coord, uSize, uContentSize));
        return;
    }
    sd = min(sd, 0.0);

    float d = circleMap(1.0 - -sd / uRefractionHeight) * uRefractionAmount;
    float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = normalize(
        gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
        uDepthEffect * normalize(centeredCoord)
    );

    vec2 refractedCoord = coord + d * grad;
    float dispersionIntensity = uChromaticAberration *
        ((centeredCoord.x * centeredCoord.y) / (halfSize.x * halfSize.y));
    vec2 dispersedCoord = d * grad * dispersionIntensity;

    vec4 color = vec4(0.0);

    vec4 red = texture(uContent, coverUv(refractedCoord + dispersedCoord, uSize, uContentSize));
    color.r += red.r / 3.5;
    color.a += red.a / 7.0;

    vec4 orange = texture(uContent, coverUv(refractedCoord + dispersedCoord * (2.0 / 3.0), uSize, uContentSize));
    color.r += orange.r / 3.5;
    color.g += orange.g / 7.0;
    color.a += orange.a / 7.0;

    vec4 yellow = texture(uContent, coverUv(refractedCoord + dispersedCoord * (1.0 / 3.0), uSize, uContentSize));
    color.r += yellow.r / 3.5;
    color.g += yellow.g / 3.5;
    color.a += yellow.a / 7.0;

    vec4 green = texture(uContent, coverUv(refractedCoord, uSize, uContentSize));
    color.g += green.g / 3.5;
    color.a += green.a / 7.0;

    vec4 cyan = texture(uContent, coverUv(refractedCoord - dispersedCoord * (1.0 / 3.0), uSize, uContentSize));
    color.g += cyan.g / 3.5;
    color.b += cyan.b / 3.0;
    color.a += cyan.a / 7.0;

    vec4 blue = texture(uContent, coverUv(refractedCoord - dispersedCoord * (2.0 / 3.0), uSize, uContentSize));
    color.b += blue.b / 3.0;
    color.a += blue.a / 7.0;

    vec4 purple = texture(uContent, coverUv(refractedCoord - dispersedCoord, uSize, uContentSize));
    color.r += purple.r / 7.0;
    color.b += purple.b / 3.0;
    color.a += purple.a / 7.0;

    fragColor = color;
}
