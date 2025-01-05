#ifndef _CAMERA_HLSL_
#define _CAMERA_HLSL_

#include "Common.hlsl"

// Converts an image position to xy in normalized device coordinates.
inline float2 iposToNDC(float2 ipos) {
    // Add 0.5 to the image position to sample the center of the pixel.
    // Map to range [0, 1] through dividing by image resolution.
    // Map to range [-1, 1], and flip y coordinate.
    return float2(ipos + 0.5) * g_view.recipRenderResolution * float2(2, -2) + float2(-1, 1);
}

// Converts an image position to xy in normalized device coordinates, and jitters the position.
inline float2 iposToNDCJittered(float2 ipos) {
    // Same procedure as above, but with added sub-pixel jitter.
    return (float2(ipos + 0.5) + g_view.subPixelJitter) * g_view.recipRenderResolution * float2(2, -2) + float2(-1, 1);
}

// Gets a primary ray direction from xy in NDC coordinates.
float3 getPrimaryRayDir(float2 posNDCXY) {
    float4 direction = mul(float4(posNDCXY, 0.5, 1), g_view.invViewProj);
    return normalize(direction.xyz / direction.w - g_view.viewOriginSteveSpace);
}

#endif