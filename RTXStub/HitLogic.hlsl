#ifndef _HITLOGIC_HLSL_
#define _HITLOGIC_HLSL_

#include "Common.hlsl"
#include "Helpers.hlsl"
#include "SurfaceInfo.hlsl"

// Returns `true` if the ray query should commit an alpha-test hit.
bool AlphaTestHitLogic(in uint instIdx, in uint triIdx, in float2 barycentrics)
{
    ObjectInstance instance = objectInstances[instIdx];
    if (instance.colourTextureIdx > 4096) false;
    float2 uv = calculateUv(triIdx, instance, barycentrics);
    float4 texel = textures[int(instance.colourTextureIdx)].SampleLevel(defaultSampler, uv, 0);
    return texel.a > 0.5;
}

// Returns `true` if the ray query should commit an alpha-blend hit.
bool AlphaBlendHitLogic(in uint instIdx, in uint triIdx, in float2 barycentrics)
{
    ObjectInstance instance = objectInstances[instIdx];
    if (instance.colourTextureIdx > 4096) return false;
    float2 uv = calculateUv(triIdx, instance, barycentrics);
    float4 texel = textures[int(instance.colourTextureIdx)].SampleLevel(defaultSampler, uv, 0);
    return texel.a == 1.0;
}

// Returns the transmission of an alpha-blend object from a ray query candidate.
float3 GetAlphaBlendTransmission(in uint instIdx, in uint triIdx, in float2 barycentrics)
{
    ObjectInstance instance = objectInstances[instIdx];
    if (instance.colourTextureIdx > 4096) return float3(1, 1, 1);
    float2 uv = calculateUv(triIdx, instance, barycentrics);
    float4 texel = textures[int(instance.colourTextureIdx)].SampleLevel(defaultSampler, uv, 0);
    return texel.rgb;
}

// Returns the transmission of water from a ray query candidate.
float3 GetWaterTransmission(in uint instIdx, in uint triIdx, in float2 barycentrics)
{
    ObjectInstance instance = objectInstances[instIdx];
    if (instance.colourTextureIdx > 4096) return float3(1, 1, 1);

    HitInfo fakeHitInfo;
    fakeHitInfo.barycentrics = barycentrics;
    fakeHitInfo.instIdx = instIdx;
    fakeHitInfo.triIdx = triIdx;

    GeometryInfo geometry = getGeometryInfo(fakeHitInfo);
    SurfaceInfo surface = getSurfaceInfo(instance, geometry);

    return surface.albedo * 0.95;
}

#endif 