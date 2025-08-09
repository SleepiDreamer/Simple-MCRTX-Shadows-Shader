#include "Atmosphere.hlsl"
#include "Camera.hlsl"
#include "BRDF.hlsl"
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
            outputBufferAlbedoAndRoughness[ipos] = float4(albedo, 0);
            outputBufferPositionAndHitT[ipos] = float4(hitPosition, MAX_RAY_DISTANCE);
            outputBufferOpacityAndObjectCategory[ipos] = float2(opacity, object.objectCategory);
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


float3 sampleSun(float3 normal, float3 origin, uint randSeed)
{    
    float3 dirToSun = g_view.directionToSun;
    float3 sunColor = g_view.sunColour;
    float intensity = sunIntensity;
    if (isSunActuallyMoon())
    {
        sunColor = float3(0.8, 0.8, 1.0) * moonIntensity;
        intensity = moonIntensity;
    }
    float maxAngle = tan(sunSizeDeg * TO_RADIANS) / 2; // Maximum angle deviation
    float3 sampleAngle = normalize(dirToSun + diskSample(randSeed, dirToSun) * maxAngle); // Add disk offset

    RayDesc ray;
    ray.Origin = offsetRay(origin, normal);
    ray.Direction = sampleAngle;
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    // Trace shadow ray
    ShadowPayload payload;
    TraceShadowRay(ray, payload);

    return intensity * payload.transmission * pow(sunColor, 1.0);
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
#if 1 // Multiple debug
    if (uv.x > 0.0) outputBufferRawFinal[ipos] = float4((octToNdirSnorm(outputBufferNormal[ipos]) + 1) / 2, 1.0);
    if (uv.x > 0.2) outputBufferRawFinal[ipos] = outputBufferEmissionAndMetalness[ipos];
    if (uv.x > 0.4) outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
    if (uv.x > 0.6) outputBufferRawFinal[ipos] = outputBufferPositionAndHitT[ipos];
    if (uv.x > 0.8) outputBufferRawFinal[ipos] = float4(outputBufferOpacityAndObjectCategory[ipos], 0.0, 1.0);
    return;
#else // Splitscreen
    if (uv.x > 0.0) 
    {
        uint2 samplePos = uint2(ipos.x - g_view.renderResolution.x / 2.0, ipos.y);
        // outputBufferRawFinal[ipos] = float4((outputBufferMotionVectors[ipos]), 0.0, 1.0);
        outputBufferRawFinal[ipos] = float4(g_view.sunColour, 1.0);
        return;
    }
#endif
#endif

    // Surface properties
    float3 albedo = pow(outputBufferAlbedoAndRoughness[ipos].rgb, 2.2);
#if WHITE_FURNACE_TEST
    albedo = float3(1.0, 1.0, 1.0); // White furnace test
#endif
    float opacity = outputBufferOpacityAndObjectCategory[ipos].x;
    float objectCategory = outputBufferOpacityAndObjectCategory[ipos].y;
    float3 emission = outputBufferEmissionAndMetalness[ipos].rgb;
    float3 normal = octToNdirSnorm(outputBufferNormal[ipos]);
    float roughness = outputBufferAlbedoAndRoughness[ipos].a;
    float metalness = outputBufferEmissionAndMetalness[ipos].a;
    float3 hitPosition = outputBufferPositionAndHitT[ipos].xyz;
    float primaryT = outputBufferPositionAndHitT[ipos].w;
    float2 prevMotionVectors = outputBufferMotionVectors[ipos].xy;

    float3 totalRadiance = 0.0;
    float3 throughput = 1.0;
    float3 steveWorldPos = g_view.waveWorksOriginInSteveSpace;
    float hitT = MAX_RAY_DISTANCE;

    RayDesc ray;
    ray.TMax = MAX_RAY_DISTANCE;
    ray.Direction = getPrimaryRayDir(ndcCoords);
    HitInfo currentHitInfo;
    currentHitInfo.clear();

    bool terminate = false;
    if (primaryT >= MAX_RAY_DISTANCE) // Sky hit
    {
        terminate = true;
        if (any(hitPosition > 0.1) && any(albedo))
        {
            totalRadiance += throughput * (albedo * 15.0) + (1.0 - albedo) * sampleSky(getPrimaryRayDir(ndcCoords)) * skyIntensity;
            // totalRadiance += float3(1.0, 0.0, 0.0);
        }
        else
        {
            totalRadiance += throughput * sampleSky(getPrimaryRayDir(ndcCoords)) * skyIntensity;
            // totalRadiance += float3(0.0, 0.0, 1.0);
        }
    }
    if (!terminate) {
        totalRadiance += throughput * emission;
        
        if (metalness < 0.5) // Dielectric surface
        {
            // --- Explicit sun sampling ---
            float pdf_sun = 0.0;
            float3 directSun = float3(0, 0, 0);
            float NdotL = saturate(dot(normal, g_view.directionToSun));
            if (NdotL > 0.0)
            {
                float3 Li = sampleSun(normal, hitPosition, randSeed);

                // Lambertian BRDF
                float3 brdf_sun = albedo * INV_PI;
                directSun = brdf_sun * Li * NdotL;

                const float halfAngleRad = sunSizeDeg * 0.5f * TO_RADIANS;
                const float omegaSun = 2.0f * PI * (1.0f - cos(halfAngleRad)); // Alternatively, use sunSizeSteradians macro

                pdf_sun = 1.0 / omegaSun;
            }


            // --- Sample next bounce direction ---
            float3 wi = float3(0, 0, 0);
            float cosTheta = 0.0;
            cosineHemisphereSample(normal, randSeed, wi, cosTheta);

            // PDF for cosine-weighted hemisphere sampling
            float pdf_brdf = cosTheta * INV_PI; 

            // Lambertian BRDF
            float3 brdf = albedo * INV_PI; 


            // --- MIS weighting ---
            float w_light = pdf_sun / (pdf_sun + pdf_brdf);
            float w_brdf = pdf_brdf / (pdf_sun + pdf_brdf);

            totalRadiance += throughput * directSun * w_light;
            throughput *= (brdf * cosTheta) / pdf_brdf;

            ray.Direction = wi;
        }
        else // Metallic surface
        {
            // TODO
            float3 wo = normalize(reflect(ray.Direction, normal) + sphereSample(randSeed) * roughness * roughness);
            float pdf = 1.0;

            ray.Direction = wo;
            totalRadiance += throughput * emission;
            throughput *= albedo * opacity * pdf;
        }
    }

    for (int bounce = 0; bounce < 2; bounce++)
    {
        if (all(ray.Direction == 0.0)) 
        {
            break;
        }
        ray.TMin = 0.0f;
        ray.Origin = offsetRay(hitPosition, normal);
        TracePrimaryRay(ray, currentHitInfo);
        if (terminate) break;
        
        // Load surface properties
        hitT = currentHitInfo.hitT;
        hitPosition = ray.Origin + hitT * ray.Direction;

        ObjectInstance object = objectInstances[currentHitInfo.instIdx];
        GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
        SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);
        
        albedo = pow(surfaceInfo.albedo.rgb, 2.2);
#if WHITE_FURNACE_TEST
        albedo = float3(1.0, 1.0, 1.0); // Wite furnace test
#endif
        opacity = surfaceInfo.opacity;
        emission = surfaceInfo.emission.rgb * emissiveIntensity;
        normal = surfaceInfo.normal;
        roughness = surfaceInfo.roughness;
        metalness = surfaceInfo.metalness;

        if (!currentHitInfo.hasHit())
        { 
            // Sky hit
            totalRadiance += throughput * sampleSky(ray.Direction) * skyIntensity;
            break;
        }
        if (object.flags & objectFlagSunOrMoon)
        { 
            // Sun/Moon hit
            totalRadiance += throughput * sampleSky(ray.Direction) * skyIntensity; // sample sky instead, reduces fireflies
            break;
        }
        else
        {
            totalRadiance += throughput * emission;

            if (metalness == 0.0) // Dielectric surface
            {
                // --- Explicit sun sampling ---
                float pdf_sun = 0.0;
                float3 directSun = float3(0, 0, 0);
                float NdotL = saturate(dot(normal, g_view.directionToSun));
                if (NdotL > 0.0)
                {
                    float3 Li = sampleSun(normal, hitPosition, randSeed);
                    // Lambertian BRDF
                    float3 brdf = albedo * INV_PI;
                    directSun = brdf * Li * NdotL;

                    const float halfAngleRad = sunSizeDeg * 0.5f * TO_RADIANS;
                    const float omegaSun = 2.0f * PI * (1.0f - cos(halfAngleRad)); // Alternatively, use sunSizeSteradians macro

                    pdf_sun = 1.0 / omegaSun;
                }


                // --- Sample next bounce direction ---
                float3 wi = float3(0, 0, 0);
                float cosTheta = 0.0;
                cosineHemisphereSample(normal, randSeed, wi, cosTheta);

                // PDF for cosine-weighted hemisphere sampling
                float pdf_brdf = cosTheta * INV_PI; 

                // Lambertian BRDF
                float3 brdf = albedo * INV_PI; 


                // --- MIS weighting ---
                float w_light = pdf_sun / (pdf_sun + pdf_brdf);
                float w_brdf = pdf_brdf / (pdf_sun + pdf_brdf);

                totalRadiance += throughput * directSun * w_light;
                throughput *= (brdf * cosTheta) / pdf_brdf;

                ray.Direction = wi;
            }

            else // Metallic surface
            {
                // TODO
                float3 wo = normalize(reflect(ray.Direction, normal) + sphereSample(randSeed) * roughness * roughness);
                float pdf = 1.0; // Simplified for metallic surfaces

                ray.Direction = wo;
                throughput *= albedo * opacity * pdf;
            }
        }

    }



#if 0 // REPROJECTION
    int2 prevIpos = int2(float2(ipos) + float2(prevMotionVectors));

    float3 reprojectedColor = lerp(totalRadiance, outputBufferPreviousSunLightShadow[prevIpos].xyz, 0.99);
    outputBufferRawFinal[ipos] = float4(reprojectedColor, 1.0);

    if (uv.x > 1.0)
    {
        // outputBufferRawFinal[ipos] = float4((prevIpos - ipos) / g_view.renderResolution, 0.0, 1.0);
        outputBufferRawFinal[ipos] = float4(prevMotionVectors, 0.0, 1.0);
    }

    outputBufferPreviousSunLightShadow[ipos] = float4(reprojectedColor, primaryT);
    // outputBufferPreviousSunLightShadow[ipos] = float4(1, 1, 1, 1);
#else
    if (AreMatricesEqual(g_view.viewProj, g_view.prevViewProj, 1e-6) && all(g_view.steveSpaceDelta == 0.0) ) 
    {
        float4 prevFrame = outputBufferPreviousSunLightShadow[ipos];
        float3 prevColour = prevFrame.rgb;
        
        uint numFramesAccumulating;
        if (outputBufferPreviousSunLightShadow[ipos].a == 0)
        {
            numFramesAccumulating = 1;
        }
        else
        {
            numFramesAccumulating = uint(prevFrame.a) + 1;
        }
        outputBufferPreviousSunLightShadow[ipos].rgb += totalRadiance;
        outputBufferPreviousSunLightShadow[ipos].a = numFramesAccumulating;
        outputBufferRawFinal[ipos] = float4(outputBufferPreviousSunLightShadow[ipos].rgb / (numFramesAccumulating + 1), 1.0);
    }
    else
    {
        outputBufferRawFinal[ipos] = float4(totalRadiance, 1);
        outputBufferPreviousSunLightShadow[ipos] = float4(totalRadiance, 0);
    }
#endif

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
//             float3 sunlight = sampleSun(normal, hitPosition, randSeed) * max(0.0, dot(normal, g_view.directionToSun));

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