#include "Atmosphere.hlsl"
#include "Camera.hlsl"
#include "Common.hlsl"
#include "Motion.hlsl"
#include "SurfaceInfo.hlsl"
#include "TraceRay.hlsl"

// The primary ray tracing pass, writing useful information to the g-buffers.
[numthreads(4, 8, 1)]
void PopulateGBuffer(uint2 ipos: SV_DispatchThreadID)
{
    // Convert image position to NDC coordinates, then use them for primary ray direction.
    float2 ndcCoords = iposToNDCJittered(ipos);
    float3 primaryDirection = getPrimaryRayDir(ndcCoords);

    // Initialize primary ray description.
    RayDesc ray;
    ray.Origin = g_view.viewOriginSteveSpace;
    ray.Direction = primaryDirection;
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    // Trace the primary ray.
    HitInfo hitInfo;
    TracePrimaryRay(ray, hitInfo);

    // Write to g-buffers according to ray traversal result.
    ObjectInstance object = objectInstances[hitInfo.instIdx];
    if (hitInfo.hasHit())
    {
        GeometryInfo geometry = getGeometryInfo(hitInfo, ray.Direction);
        SurfaceInfo surface = getSurfaceInfo(object, geometry);

        float3 hitPosition = g_view.viewOriginSteveSpace + hitInfo.hitT * primaryDirection;
        outputBufferPositionAndHitT[ipos] = float4(hitPosition, hitInfo.hitT);
        outputBufferPrimaryPathLength[ipos] = hitInfo.hitT;

        outputBufferObjectInstanceIndex[ipos] = hitInfo.instIdx;
        outputBufferMotionVectors[ipos] = computeObjectMotionVector(hitPosition, geometry.motion);

        outputBufferNormal[ipos] = ndirToOctSnorm(surface.normal);
        outputBufferGeometryNormal[ipos] = ndirToOctSnorm(geometry.normal);
        outputBufferAlbedoAndRoughness[ipos] = float4(surface.albedo, surface.roughness);
        outputBufferEmissionAndMetalness[ipos] = float4(surface.emission, surface.metalness);
        outputBufferOpacityAndObjectCategory[ipos] = float2(surface.opacity, object.objectCategory);
    }
    else
    {
        outputBufferPositionAndHitT[ipos] = float4(primaryDirection, MAX_RAY_DISTANCE);
        outputBufferPrimaryPathLength[ipos] = MAX_RAY_DISTANCE;

        float2 mvecs = computeEnvironmentMotionVector(primaryDirection);
        outputBufferMotionVectors[ipos] = mvecs;
    }

    // Get throughput along the ray. This is mainly used to render alpha-blending objects.
    float3 throughput;
    TraceThroughputRay(ray, throughput);
    outputBufferPrimaryThroughput[ipos] = float4(throughput, 0);
}

// The intensity of sunlight.
static const float sunIntensity = 0.75;

// Trace shadow rays to gether incident sunlight.
[numthreads(4, 8, 1)]
void SunShadows(uint2 ipos: SV_DispatchThreadID)
{
    // Pull position and normal from g-buffers.
    float4 positionAndHitT = inputBufferPositionAndHitT[ipos];
    float3 normal = octToNdirSnorm(inputBufferNormal[ipos]);
    // Compute cosine of sunlight direction and normal.
    float NdotS = dot(normal, g_view.directionToSun);
    // Custom fade set up to still include perpendicular sun light on surfaces.
    float sunFade = smoothstep(-0.2, 0.1, NdotS);

    if (inputBufferPrimaryPathLength[ipos] == MAX_RAY_DISTANCE || sunFade == 0.0)
    {
        outputBufferSunLight[ipos] = 0;
        return;
    }

    // Setup the shadow ray.
    RayDesc ray;
    ray.Origin = positionAndHitT.xyz + 1.0e-5 * normal;
    ray.Direction = g_view.directionToSun;
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    // Trace shadow ray and write resulting sunlight value.
    ShadowPayload payload;
    TraceShadowRay(ray, payload);

    float3 sunlight = g_view.sunColour * sunIntensity * sunFade * payload.transmission;

    outputBufferSunLight[ipos] = float4(sunlight, 1.0);
}

// Adds ambient lighting to every surface, slightly proportional
// to the sunlight direction.
[numthreads(4, 8, 1)]
void DiffuseLighting(uint2 ipos: SV_DispatchThreadID)
{
    float3 normal = octToNdirSnorm(inputBufferNormal[ipos]);
    float NdotS = dot(normal, g_view.directionToSun);

    float3 ambient = 0;
    if (inputBufferPrimaryPathLength[ipos] < MAX_RAY_DISTANCE)
        ambient = lerp(0.5, 0.7, remap(NdotS, -1.0, 1.0));
    outputBufferDiffuse[ipos] = float4(ambient, 0.0);
}

// Entry Points
[numthreads(4, 8, 1)]
void AdaptiveDenoiserCalculateGradientsInline(uint2 launchIndex: SV_DispatchThreadID)
{
}

[numthreads(4, 8, 1)]
void AdaptiveDenoiserGenerateReferenceInline(uint2 launchIndex: SV_DispatchThreadID)
{
}

[numthreads(4, 8, 1)]
void RefractionRayGenInline(uint2 launchIndex: SV_DispatchThreadID)
{
}

[numthreads(4, 8, 1)]
void ExplicitLightSamplingInline(uint2 launchIndex: SV_DispatchThreadID)
{
}

// The intensity multiplier for emissive surfaces.
static const float emissiveIntensity = 2.0;

// Combine lighting information into the raw HDR render output.
[numthreads(4, 8, 1)]
void AccumulateLighting(uint2 ipos: SV_DispatchThreadID)
{
    if (any(ipos >= g_view.renderResolution))
    {
        outputBufferFinal[ipos] = 0;
        return;
    }

    ObjectInstance object = objectInstances[inputBufferObjectInstanceIndex[ipos]];

    float2 opacityAndCategory = inputBufferOpacityAndObjectCategory[ipos];
    float4 albedoAndRoughness = inputBufferAlbedoAndRoughness[ipos];
    float4 emissionAndMetalness = inputBufferEmissionAndMetalness[ipos];
    float4 positionAndHitT = inputBufferPositionAndHitT[ipos];
    float3 normal = octToNdirSnorm(inputBufferNormal[ipos]);
    float3 finalColour = 0;

    // If the primary ray hit anything, shade it accordingly. Else sample the sky.
    if (inputBufferPrimaryPathLength[ipos] < MAX_RAY_DISTANCE)
    {
        if (object.flags & objectFlagSunOrMoon)
        {
            finalColour = screen(sampleSky(normalize(positionAndHitT.xyz)), albedoAndRoughness.rgb) + albedoAndRoughness.rgb;
        }
        else
        {
            float3 emission = emissionAndMetalness.rgb;
            float3 indirectDiffuse = inputBufferDiffuse[ipos].rgb;
            float3 sunlight = inputBufferSunLight[ipos].rgb;

            float3 albedo = albedoAndRoughness.rgb;
            float3 diffuse = indirectDiffuse + sunlight;

            finalColour = emission * emissiveIntensity + albedo * diffuse;
        }
    }
    else
        finalColour = sampleSky(positionAndHitT.xyz);

    // Apply throughput value to accumulated lighting.
    float3 primaryThroughput = inputBufferPrimaryThroughput[ipos].rgb;
    outputBufferRawFinal[ipos] = float4(finalColour * primaryThroughput, 1.0);
}

[numthreads(4, 8, 1)]
void PathTracingRayGenInline(uint2 launchIndex: SV_DispatchThreadID)
{
}
