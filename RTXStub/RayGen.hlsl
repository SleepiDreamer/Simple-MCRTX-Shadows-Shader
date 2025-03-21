#include "Atmosphere.hlsl"
#include "Camera.hlsl"
#include "Common.hlsl"
#include "Random.hlsl"
#include "Motion.hlsl"
#include "SurfaceInfo.hlsl"
#include "TraceRay.hlsl"

[numthreads(4, 8, 1)]
void DiffuseLighting(uint2 ipos: SV_DispatchThreadID)
{
}

[numthreads(4, 8, 1)]
void SunShadows(uint2 ipos: SV_DispatchThreadID)
{
}

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

static const float emissiveIntensity = 100.0;
static const float sunSizeDeg = 0.53; // Real-world value is 0.53
static const float sunIntensity = 3.0;

// The primary ray tracing pass, writing useful information to the g-buffers.
[numthreads(4, 8, 1)]
void PopulateGBuffer(uint2 ipos: SV_DispatchThreadID)
{
    uint randSeed = initSeed(ipos, g_view.frameCount);
    float2 ndcCoords = iposToNDCJittered(ipos);
    float2 uv = ipos / g_view.renderResolution;

    if (any(ipos >= g_view.renderResolution) || any(ipos < 0))
    {
        outputBufferRawFinal[ipos] = 0;
        return;
    }

    // Trace ray
    RayDesc ray;
    ray.Origin = g_view.viewOriginSteveSpace;
	ray.Direction = getPrimaryRayDir(ndcCoords);
	ray.TMin = 0.001f;
	ray.TMax = MAX_RAY_DISTANCE;
    float hitT = MAX_RAY_DISTANCE;

    HitInfo currentHitInfo;
    currentHitInfo.clear();
    TracePrimaryRay(ray, currentHitInfo);
    hitT = currentHitInfo.hitT;

    // Load surface properties
    ObjectInstance object = objectInstances[currentHitInfo.instIdx];
    GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
    SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);

    // Retrieve surface properties
    float3 hitPosition = ray.Origin + currentHitInfo.hitT * ray.Direction;
    float3 albedo = surfaceInfo.albedo.rgb;
    float opacity = surfaceInfo.opacity;
    float3 emission = surfaceInfo.emission.rgb * emissiveIntensity;
    float3 normal = surfaceInfo.normal;
    float roughness = surfaceInfo.roughness;
    float metalness = surfaceInfo.metalness;
    float3 motion = geometryInfo.motion;

    // Convert properties to buffer format
    float4 albedoAndRoughness = float4(albedo, roughness);
    float4 emissionAndMetalness = float4(emission, metalness);
    float2 opacityAndCategory = float2(opacity, object.objectCategory);
    float3 worldPos = hitPosition - g_view.waveWorksOriginInSteveSpace;
    worldPos = worldPos - floor(worldPos / 1024) * 1024;

    // Populate GBuffer
    bool isInSky = !currentHitInfo.hasHit() || (object.flags & objectFlagSunOrMoon);
    if (isInSky)
    { 
        // Sky
        outputBufferPositionAndHitT[ipos] = float4(0..xxx, MAX_RAY_DISTANCE);
        outputBufferAlbedoAndRoughness[ipos] = float4(0..xxx, 0);
        outputBufferEmissionAndMetalness[ipos] = float4(0..xxx, 0);
        outputBufferOpacityAndObjectCategory[ipos] = float2(1, -1);
        outputBufferNormal[ipos] = ndirToOctSnorm(-ray.Direction);
        outputBufferObjectInstanceIndex[ipos] = currentHitInfo.instIdx;
        outputBufferMotionVectors[ipos] = computeEnvironmentMotionVector(ray.Direction);
        if (object.flags & objectFlagSunOrMoon)
        { 
            // Sun/moon
            outputBufferPositionAndHitT[ipos] = float4(hitPosition, MAX_RAY_DISTANCE);
        }
    }
    else
    { 
        // Regular object
        outputBufferPositionAndHitT[ipos] = float4(hitPosition, currentHitInfo.hitT);
        outputBufferAlbedoAndRoughness[ipos] = float4(albedo, roughness);
        outputBufferEmissionAndMetalness[ipos] = float4(emission, metalness);
        outputBufferOpacityAndObjectCategory[ipos] = float2(opacity, object.objectCategory);
        outputBufferNormal[ipos] = ndirToOctSnorm(normal);
        outputBufferObjectInstanceIndex[ipos] = currentHitInfo.instIdx;
        outputBufferMotionVectors[ipos] = computeObjectMotionVector(hitPosition, motion);
        // outputBufferMotionVectors[ipos] = computeEnvironmentMotionVector(ray.Direction) + computeObjectMotionVector(worldPos, motion);
    }
}


float3 GetSunLight(float3 normal, float3 origin, uint randSeed)
{    
    // Sample direction
    float3 dirToSun = g_view.directionToSun;
    float maxAngle = tan(sunSizeDeg * TO_RADIANS) / 2; // Maximum angle deviation
    float3 sampleAngle = normalize(dirToSun + diskSample(randSeed, dirToSun) * maxAngle); // Add disk offset

    RayDesc ray;
    ray.Origin = offsetRay(origin, normal);
    ray.Direction = sampleAngle;
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    float NdotS = dot(normal, sampleAngle);
#if 0
    // Custom fade set up to still include perpendicular sun light on surfaces.
    float sunFade = smoothstep(-0.2, 0.1, NdotS);
#else
    float sunFade = saturate(NdotS);
#endif
    // Trace shadow ray
    ShadowPayload payload;
    TraceShadowRay(ray, payload);

    // float3 sunlight = g_view.sunColour * sunIntensity * sunFade * payload.transmission;
    return sunIntensity * sunFade * payload.transmission;
}


[numthreads(4, 8, 1)]
void PathTracingRayGenInline(uint2 ipos: SV_DispatchThreadID)
{
    uint randSeed = initSeed(ipos, g_view.frameCount);
    float2 ndcCoords = iposToNDCJittered(ipos);
    float2 uv = ipos / g_view.renderResolution;

    if (any(ipos >= g_view.renderResolution) || any(ipos < 0))
    {
        outputBufferFinal[ipos] = 0;
        return;
    }

#if 0 // Debug view
    if (uv.x > 0.0) outputBufferRawFinal[ipos] = float4((octToNdirSnorm(outputBufferNormal[ipos]) + 1) / 2, 1.0);
    if (uv.x > 0.2) outputBufferRawFinal[ipos] = outputBufferEmissionAndMetalness[ipos];
    if (uv.x > 0.4) outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
    if (uv.x > 0.6) outputBufferRawFinal[ipos] = outputBufferPositionAndHitT[ipos];
    if (uv.x > 0.8) outputBufferRawFinal[ipos] = float4(outputBufferOpacityAndObjectCategory[ipos], 0.0, 1.0);
    return;
#endif

    // Surface properties
    float3 albedo = outputBufferAlbedoAndRoughness[ipos].rgb;
    float opacity = outputBufferOpacityAndObjectCategory[ipos].x;
    float3 emission = outputBufferEmissionAndMetalness[ipos].rgb;
    float3 normal = octToNdirSnorm(outputBufferNormal[ipos]);
    float roughness = outputBufferAlbedoAndRoughness[ipos].a;
    float metalness = outputBufferEmissionAndMetalness[ipos].a;
    float3 hitPosition = outputBufferPositionAndHitT[ipos].xyz;
    float primaryT = outputBufferPositionAndHitT[ipos].w;
    float objectCategory = outputBufferOpacityAndObjectCategory[ipos].y;

    float3 totalRadiance = 0.0;
    float3 throughput = 1.0;
    float3 steveWorldPos = g_view.waveWorksOriginInSteveSpace;
    float hitT = MAX_RAY_DISTANCE;

    RayDesc ray;
    ray.TMax = MAX_RAY_DISTANCE;
    HitInfo currentHitInfo;
    currentHitInfo.clear();

    bool terminate = false;
    if (primaryT >= MAX_RAY_DISTANCE) // Sky hit
    {
        terminate = true;
        totalRadiance += sampleSky(getPrimaryRayDir(ndcCoords)) / skyIntensity;
        // if (any(hitPosition > 0.1))
        // {
        //     totalRadiance += screen(sampleSky(normalize(hitPosition)), albedo);
        // }
    }
    totalRadiance += emission + albedo * GetSunLight(normal, hitPosition, randSeed);
    throughput *= albedo;

    for (int bounce = 0; bounce < 3; bounce++)
    {
        if (terminate) break;
        ray.Origin = offsetRay(hitPosition, normal);
        ray.Direction = hemisphereSample(randSeed, normal);
        ray.TMin = 0.0f;
        TracePrimaryRay(ray, currentHitInfo);
        
        // Load surface properties
        hitT = currentHitInfo.hitT;
        hitPosition = ray.Origin + hitT * ray.Direction;

        ObjectInstance object = objectInstances[currentHitInfo.instIdx];
        GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
        SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);
        
        albedo = surfaceInfo.albedo.rgb;
        opacity = surfaceInfo.opacity;
        emission = surfaceInfo.emission.rgb * emissiveIntensity;
        normal = surfaceInfo.normal;
        roughness = surfaceInfo.roughness;
        metalness = surfaceInfo.metalness;

        if (!currentHitInfo.hasHit())
        { 
            // Sky hit
            totalRadiance += throughput * sampleSky(ray.Direction);
            break;
        }
        if (object.flags & objectFlagSunOrMoon)
        { 
            // Sun/Moon hit
            totalRadiance += throughput * sampleSky(ray.Direction); // sample sky instead
            break;
        }
        else
        {
            float3 sunlight = GetSunLight(normal, hitPosition, randSeed) * max(0.0, dot(normal, g_view.directionToSun));

            float3 radiance = emission + albedo * sunlight;

            totalRadiance += throughput * radiance;
            throughput *= albedo * opacity;
        }
    }

    float4 finalColour = float4(totalRadiance, 1.0);
    if (AreMatricesEqual(g_view.viewProj, g_view.prevViewProj, 1e-6)) 
    {
        finalColour = lerp(finalColour, outputBufferPreviousSunLightShadow[ipos], 0.98);
    }

    outputBufferPreviousSunLightShadow[ipos] = finalColour;
    outputBufferRawFinal[ipos] = finalColour;

//     float3 finalColour = 0.0f;
//     float3 totalRadiance = 0.0f;
//     float3 throughput = 1.0f;
//     float hitT = MAX_RAY_DISTANCE;
//     RayDesc ray;

// 	ray.Origin = g_view.viewOriginSteveSpace;
// 	ray.Direction = getPrimaryRayDir(ndcCoords);
// 	ray.TMin = 0.001f;
// 	ray.TMax = MAX_RAY_DISTANCE;

//     for (int bounce = 0; bounce < 4; bounce++)
//     {
//         HitInfo currentHitInfo;
//         currentHitInfo.clear();

//         // Trace ray
//         ray.TMin = 0.0f;
//         TracePrimaryRay(ray, currentHitInfo);
//         hitT = currentHitInfo.hitT;

//         // Load surface properties
//         ObjectInstance object = objectInstances[currentHitInfo.instIdx];
//         GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
//         SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);
//         float3 surfaceTransmission = lerp(surfaceInfo.albedo.rgb, 0..xxx, surfaceInfo.opacity);

//         float3 hitPosition = ray.Origin + currentHitInfo.hitT * ray.Direction;
        
//         float3 albedo = surfaceInfo.albedo.rgb;
//         float opacity = surfaceInfo.opacity;
//         float3 emission = surfaceInfo.emission.rgb * emissiveIntensity;
//         float3 normal = surfaceInfo.normal;
//         float roughness = surfaceInfo.roughness;
//         float metalness = surfaceInfo.metalness;
        
//         // outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
//         // return;

//         if (!currentHitInfo.hasHit())
//         {
//             // Sky hit
//             totalRadiance += throughput * sampleSky(ray.Direction);
//             break;
//         }
//         if (object.flags & objectFlagSunOrMoon)
//         {
//             // Sun/Moon hit
//             totalRadiance += throughput * (screen(sampleSky(normalize(hitPosition)), albedo) + albedo);
//             break;
//         }
//         else
//         {
//             float3 sunlight = GetSunLight(normal, hitPosition, randSeed) * max(0.0, dot(normal, g_view.directionToSun));

//             float3 radiance = emission + albedo * sunlight;

//             totalRadiance += throughput * radiance;
//             throughput *= albedo * opacity;

//             // if (length(throughput) < 0.01)
//             // {
//             //     break;
//             // }
//         }

//         // Russian Roulette
//         // if (bounce > 3) {
//         //     float p = max(throughput.x, max(throughput.y, throughput.z));
//         //     if (nextSeedFloat(randSeed) > p) {
//         //         break;
//         //     }

//         //     throughput /= p;
//         // }

//         ray.Origin = offsetRay(hitPosition, normal);
//         ray.Direction = hemisphereSample(randSeed, normal);
//     } 
    
//     finalColour = totalRadiance;

//     // Apply throughput value to accumulated lighting.
//     float3 primaryThroughput = inputBufferPrimaryThroughput[ipos].rgb;
// #if 1 // Debug
//     outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
//     if (uv.x > 0.25) outputBufferRawFinal[ipos] = float4(outputBufferGeometryNormal[ipos], 0.0, 1.0);
//     if (uv.x > 0.5) outputBufferRawFinal[ipos] = outputBufferEmissionAndMetalness[ipos];
//     if (uv.x > 0.75) outputBufferRawFinal[ipos] = float4(finalColour, 1.0);
// #else
//     outputBufferRawFinal[ipos] = float4(finalColour * primaryThroughput, 1.0);
// #endif
}