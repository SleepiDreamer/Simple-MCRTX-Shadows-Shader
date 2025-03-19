#include "Atmosphere.hlsl"
#include "Camera.hlsl"
#include "Common.hlsl"
#include "Random.hlsl"
#include "Motion.hlsl"
#include "SurfaceInfo.hlsl"
#include "TraceRay.hlsl"

// The primary ray tracing pass, writing useful information to the g-buffers.
[numthreads(4, 8, 1)]
void PopulateGBuffer(uint2 ipos: SV_DispatchThreadID)
{
    // // Convert image position to NDC coordinates, then use them for primary ray direction.
    // float2 ndcCoords = iposToNDCJittered(ipos);
    // float3 primaryDirection = getPrimaryRayDir(ndcCoords);

    // // Initialize primary ray description.
    // RayDesc ray;
    // ray.Origin = g_view.viewOriginSteveSpace;
    // ray.Direction = primaryDirection;
    // ray.TMin = 0.0;
    // ray.TMax = MAX_RAY_DISTANCE;

    // // Trace the primary ray.
    // HitInfo hitInfo;
    // TracePrimaryRay(ray, hitInfo);

    // // Write to g-buffers according to ray traversal result.
    // ObjectInstance object = objectInstances[hitInfo.instIdx];
    // if (hitInfo.hasHit())
    // {
    //     GeometryInfo geometry = getGeometryInfo(hitInfo, ray.Direction);
    //     SurfaceInfo surface = getSurfaceInfo(object, geometry);

    //     float3 hitPosition = g_view.viewOriginSteveSpace + hitInfo.hitT * primaryDirection;
    //     outputBufferPositionAndHitT[ipos] = float4(hitPosition, hitInfo.hitT);
    //     outputBufferPrimaryPathLength[ipos] = hitInfo.hitT;

    //     outputBufferObjectInstanceIndex[ipos] = hitInfo.instIdx;
    //     outputBufferMotionVectors[ipos] = computeObjectMotionVector(hitPosition, geometry.motion);

    //     outputBufferNormal[ipos] = ndirToOctSnorm(surface.normal);
    //     outputBufferGeometryNormal[ipos] = ndirToOctSnorm(geometry.normal);
    //     outputBufferAlbedoAndRoughness[ipos] = float4(surface.albedo, surface.roughness);
    //     outputBufferEmissionAndMetalness[ipos] = float4(surface.emission, surface.metalness);
    //     outputBufferOpacityAndObjectCategory[ipos] = float2(surface.opacity, object.objectCategory);
    // }
    // else
    // {
    //     outputBufferPositionAndHitT[ipos] = float4(primaryDirection, MAX_RAY_DISTANCE);
    //     outputBufferPrimaryPathLength[ipos] = MAX_RAY_DISTANCE;

    //     float2 mvecs = computeEnvironmentMotionVector(primaryDirection);
    //     outputBufferMotionVectors[ipos] = mvecs;
    // }

    // // Get throughput along the ray. This is mainly used to render alpha-blending objects.
    // float3 throughput;
    // TraceThroughputRay(ray, throughput);
    // outputBufferPrimaryThroughput[ipos] = float4(throughput, 0);
}

// The intensity of sunlight.
static const float sunIntensity = 2.0f;

// Trace shadow rays to gether incident sunlight.
[numthreads(4, 8, 1)]
void SunShadows(uint2 ipos: SV_DispatchThreadID)
{
    // // Pull position and normal from g-buffers.
    // float4 positionAndHitT = inputBufferPositionAndHitT[ipos];
    // float3 normal = octToNdirSnorm(inputBufferNormal[ipos]);
    // // Compute cosine of sunlight direction and normal.
    // float NdotS = dot(normal, g_view.directionToSun);
    // // Custom fade set up to still include perpendicular sun light on surfaces.
    // float sunFade = smoothstep(-0.2, 0.1, NdotS);

    // if (inputBufferPrimaryPathLength[ipos] == MAX_RAY_DISTANCE || sunFade == 0.0)
    // {
    //     outputBufferSunLight[ipos] = 0;
    //     return;
    // }

    // // Setup the shadow ray.
    // RayDesc ray;
    // ray.Origin = positionAndHitT.xyz + 1.0e-5 * normal;
    // ray.Direction = g_view.directionToSun;
    // ray.TMin = 0.0;
    // ray.TMax = MAX_RAY_DISTANCE;

    // // Trace shadow ray and write resulting sunlight value.
    // ShadowPayload payload;
    // TraceShadowRay(ray, payload);

    // float3 sunlight = g_view.sunColour * sunIntensity * sunFade * payload.transmission;

    // outputBufferSunLight[ipos] = float4(sunlight, 1.0);
}

const float sunSizeDeg = 3.0f;

float3 GetSunLight(float3 normal, float3 origin, uint randSeed)
{
    RayDesc ray;
    ray.Origin = offsetRay(origin, normal);
    ray.Direction = normalize(g_view.directionToSun + 0.05 * (hemisphereSample(randSeed, normal) - 0.05f));
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    float3 hitPosition = ray.Origin + ray.TMax * ray.Direction;
    float NdotS = dot(normal, g_view.directionToSun);

    // Custom fade set up to still include perpendicular sun light on surfaces.
    float sunFade = smoothstep(-0.2, 0.1, NdotS);

    // Trace shadow ray
    ShadowPayload payload;
    TraceShadowRay(ray, payload);

    // float3 sunlight = g_view.sunColour * sunIntensity * sunFade * payload.transmission;
    return sunIntensity * sunFade * payload.transmission;
}

// Adds ambient lighting to every surface, slightly proportional
// to the sunlight direction.
[numthreads(4, 8, 1)]
void DiffuseLighting(uint2 ipos: SV_DispatchThreadID)
{
    // float3 normal = octToNdirSnorm(inputBufferNormal[ipos]);
    // float NdotS = dot(normal, g_view.directionToSun);

    // float3 ambient = 0;
    // if (inputBufferPrimaryPathLength[ipos] < MAX_RAY_DISTANCE)
    //     ambient = lerp(0.5, 0.7, remap(NdotS, -1.0, 1.0));
    // outputBufferDiffuse[ipos] = float4(ambient, 0.0);
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
static const float emissiveIntensity = 500.0;

[numthreads(4, 8, 1)]
void PathTracingRayGenInline(uint2 ipos: SV_DispatchThreadID)
{
    uint randSeed = initSeed(ipos, g_view.frameCount);
    float2 ndcCoords = iposToNDCJittered(ipos);

    if (any(ipos >= g_view.renderResolution) || any(ipos < 0))
    {
        outputBufferFinal[ipos] = 0;
        return;
    }

    float3 finalColour = 0.0f;
    float3 totalRadiance = 0.0f;
    float3 throughput = 1.0f;
    float hitT = MAX_RAY_DISTANCE;
    RayDesc ray;

	ray.Origin = g_view.viewOriginSteveSpace;
	ray.Direction = getPrimaryRayDir(ndcCoords);
	ray.TMin = 0.001f;
	ray.TMax = MAX_RAY_DISTANCE;

    for (int bounce = 0; bounce < 4; bounce++)
    {
        HitInfo currentHitInfo;
        currentHitInfo.clear();

        // Trace ray
        ray.TMin = 0.0f;
        TracePrimaryRay(ray, currentHitInfo);
        hitT = currentHitInfo.hitT;

        // Load surface properties
        ObjectInstance object = objectInstances[currentHitInfo.instIdx];
        GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
        SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);
        float3 surfaceTransmission = lerp(surfaceInfo.albedo.rgb, 0..xxx, surfaceInfo.opacity);

        float3 hitPosition = ray.Origin + currentHitInfo.hitT * ray.Direction;
        
        float3 albedo = surfaceInfo.albedo.rgb;
        float opacity = surfaceInfo.opacity;
        float3 emission = surfaceInfo.emission.rgb * emissiveIntensity;
        float3 normal = surfaceInfo.normal;
        float roughness = surfaceInfo.roughness;
        float metalness = surfaceInfo.metalness;
        
        // outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
        // return;

        if (bounce == 0)
        { // Populate GBuffer
            float2 geometryNormal = ndirToOctSnorm(normal);
            float4 albedoAndRoughness = float4(albedo, roughness);
            float4 emissionAndMetalness = float4(emission, metalness);
            float2 opacityAndCategory = float2(opacity, object.objectCategory);

            if (currentHitInfo.hasHit())
            {
                float3 hitPosition = g_view.viewOriginSteveSpace + currentHitInfo.hitT * ray.Direction;
                outputBufferPositionAndHitT[ipos] = float4(hitPosition, currentHitInfo.hitT);
                outputBufferPrimaryPathLength[ipos] = currentHitInfo.hitT;

                outputBufferObjectInstanceIndex[ipos] = currentHitInfo.instIdx;
                outputBufferMotionVectors[ipos] = computeObjectMotionVector(hitPosition, geometryInfo.motion);

                outputBufferNormal[ipos] = ndirToOctSnorm(normal);
                outputBufferGeometryNormal[ipos] = geometryNormal;
                outputBufferAlbedoAndRoughness[ipos] = albedoAndRoughness;
                outputBufferEmissionAndMetalness[ipos] = emissionAndMetalness;
                outputBufferOpacityAndObjectCategory[ipos] = opacityAndCategory;

                float2 mvecs = computeEnvironmentMotionVector(ray.Direction);
                outputBufferMotionVectors[ipos] = mvecs;
            }
            else
            {
                outputBufferPositionAndHitT[ipos] = float4(ray.Direction, MAX_RAY_DISTANCE);
                outputBufferPrimaryPathLength[ipos] = MAX_RAY_DISTANCE;

                outputBufferObjectInstanceIndex[ipos] = 0;
                outputBufferMotionVectors[ipos] = float2(0, 0);

                outputBufferNormal[ipos] = float4(0, 0, 0, 0);
                outputBufferGeometryNormal[ipos] = float4(0, 0, 0, 0);
                outputBufferAlbedoAndRoughness[ipos] = float4(0, 0, 0, 0);
                outputBufferEmissionAndMetalness[ipos] = float4(0, 0, 0, 0);
                outputBufferOpacityAndObjectCategory[ipos] = float2(0, 0);

                float2 mvecs = computeEnvironmentMotionVector(ray.Direction);
                outputBufferMotionVectors[ipos] = mvecs;
            }
        }

        if (!currentHitInfo.hasHit())
        {
            // Sky hit
            totalRadiance += throughput * sampleSky(ray.Direction);
            break;
        }
        if (object.flags & objectFlagSunOrMoon)
        {
            // Sun/Moon hit
            totalRadiance += throughput * (screen(sampleSky(normalize(hitPosition)), albedo) + albedo);
            break;
        }
        else
        {
            float3 sunlight = GetSunLight(normal, hitPosition, randSeed) * max(0.0, dot(normal, g_view.directionToSun));

            float3 radiance = emission + albedo * sunlight;

            totalRadiance += throughput * radiance;
            throughput *= albedo * opacity;

            // if (length(throughput) < 0.01)
            // {
            //     break;
            // }
        }

        // Russian Roulette
        // if (bounce > 3) {
        //     float p = max(throughput.x, max(throughput.y, throughput.z));
        //     if (nextSeedFloat(randSeed) > p) {
        //         break;
        //     }

        //     throughput /= p;
        // }

        ray.Origin = offsetRay(hitPosition, normal);
        ray.Direction = hemisphereSample(randSeed, normal);
    } 
    
    finalColour = totalRadiance;

    // Apply throughput value to accumulated lighting.
    float3 primaryThroughput = inputBufferPrimaryThroughput[ipos].rgb;
#if 1 // Debug
    float2 uv = ipos / g_view.renderResolution;
    outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
    if (uv.x > 0.25) outputBufferRawFinal[ipos] = float4(outputBufferGeometryNormal[ipos], 0.0, 1.0);
    if (uv.x > 0.5) outputBufferRawFinal[ipos] = outputBufferEmissionAndMetalness[ipos];
    if (uv.x > 0.75) outputBufferRawFinal[ipos] = float4(finalColour, 1.0);
#else
    outputBufferRawFinal[ipos] = float4(finalColour * primaryThroughput, 1.0);
#endif
}