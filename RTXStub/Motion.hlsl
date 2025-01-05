#ifndef _MOTION_HLSL_
#define _MOTION_HLSL_

#include "Common.hlsl"

// Computes a motion vector relative to the world space position and motion of an object.
float2 computeObjectMotionVector(in float3 position, in float3 motion)
{
    float3 prevPosition = position - motion;
    float4 clipPos = mul(float4(position, 1), g_view.viewProj);
    float4 prevClipPos = mul(float4(prevPosition, 1), g_view.prevViewProj);
    float2 ndcPos = clipPos.xy / clipPos.ww;
    float2 prevNdcPos = prevClipPos.xy / prevClipPos.ww;

    // outReprojectedHitT = length(prevSteveSpacePos - g_view.previousViewOriginSteveSpace);

    // Expressed as a UV difference in NDC coordinates.
    float2 currentToPreviousNdcXy = prevNdcPos - ndcPos;
    return currentToPreviousNdcXy * float2(0.5f, -0.5f);
}

// Computes a motion vector relative to a view direction.
float2 computeEnvironmentMotionVector(float3 viewDirection)
{
    float4 clipPos = mul(float4(viewDirection, 0), g_view.viewProj);
    float4 prevClipPos = mul(float4(viewDirection, 0), g_view.prevViewProj);

    if (clipPos.w <= 0 || prevClipPos.w <= 0) return 0;

    float2 ndcPos = clipPos.xy / clipPos.ww;
    float2 prevNdcPos = prevClipPos.xy / prevClipPos.ww;

    // Expressed as a UV difference in NDC coordinates.
    float2 currentToPreviousNdcXy = prevNdcPos - ndcPos;
    return currentToPreviousNdcXy * float2(0.5f, -0.5f);
}

#endif