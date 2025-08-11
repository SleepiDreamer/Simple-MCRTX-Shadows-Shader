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

[numthreads(1, 1, 1)]
void Dummy(uint2 launchIndex: SV_DispatchThreadID)
{
    return;
}

// The primary ray tracing pass, writing useful information to the g-buffers.
[numthreads(4, 8, 1)]
void PopulateGBuffer(uint2 ipos: SV_DispatchThreadID, const bool hitSky, const float3 rayDirection, const float4 positionAndHitT, const float4 albedoAndRoughness, 
                    const float4 emissionAndMetalness, const float2 opacityAndObjectCategory, const float3 normal, uint instIdx, float3 motion)
{
    if (hitSky)
    { 
        // Sky
        outputBufferPositionAndHitT[ipos] = float4(0..xxx, MAX_RAY_DISTANCE);
        outputBufferAlbedoAndRoughness[ipos] = float4(0..xxx, 0);
        outputBufferEmissionAndMetalness[ipos] = float4(0..xxx, 0);
        outputBufferOpacityAndObjectCategory[ipos] = float2(1, -1);
        outputBufferNormal[ipos] = ndirToOctSnorm(-rayDirection);
        outputBufferObjectInstanceIndex[ipos] = instIdx;
        outputBufferMotionVectors[ipos] = computeEnvironmentMotionVector(rayDirection);
    }
    else
    { 
        // Regular object
        outputBufferPositionAndHitT[ipos] = float4(positionAndHitT.xyz, positionAndHitT.w);
        outputBufferAlbedoAndRoughness[ipos] = float4(albedoAndRoughness.rgb, albedoAndRoughness.a);
        outputBufferEmissionAndMetalness[ipos] = float4(emissionAndMetalness.rgb, emissionAndMetalness.a);
        outputBufferOpacityAndObjectCategory[ipos] = float2(opacityAndObjectCategory.x, opacityAndObjectCategory.y);
        outputBufferNormal[ipos] = ndirToOctSnorm(normal);
        outputBufferObjectInstanceIndex[ipos] = instIdx;
        outputBufferMotionVectors[ipos] = computeObjectMotionVector(positionAndHitT.xyz, motion);
    }
}


float3 sampleSun(float3 normal, float3 origin, float2 random)
{    
    float3 dirToSun = getDirectionToSun();
    float3 sunColor = getSunColor();

    float maxAngle = tan(sunSizeDeg * TO_RADIANS) / 2; // Maximum angle deviation
    float3 sampleAngle = normalize(dirToSun + diskSample(random, dirToSun) * maxAngle); // Add disk offset

    RayDesc ray;
    ray.Origin = offsetRay(origin, normal);
    ray.Direction = sampleAngle;
    ray.TMin = 0.0;
    ray.TMax = MAX_RAY_DISTANCE;

    // Trace shadow ray
    ShadowPayload payload;
    TraceShadowRay(ray, payload);

    return payload.transmission * pow(sunColor, 1.0);
}


[numthreads(4, 8, 1)]
void PathTracingRayGenInline(uint2 ipos: SV_DispatchThreadID)
{
    uint randSeed = initSeed(ipos, g_view.frameCount);
    float2 ndcCoords = iposToNDCJittered(ipos);
    float2 uv = ipos / g_view.renderResolution;

    if (any(ipos >= g_view.renderResolution) || any(ipos < 0))
    {
        return;
    }

    float3 totalRadiance = 0.0;
    float3 throughput = float3(1,1,1);
    float3 hitPosition = g_view.viewOriginSteveSpace;

    RayDesc ray;
    ray.Origin = g_view.viewOriginSteveSpace;
    ray.Direction = getPrimaryRayDir(ndcCoords);
    ray.TMin = 0.0001f;
    ray.TMax = MAX_RAY_DISTANCE;
    float hitT = MAX_RAY_DISTANCE;

    [unroll]
    for (int bounce = 0; bounce < 3; bounce++)
    {
        // Trace ray
        ray.TMin = 0.0001f;
        ray.Origin = offsetRay(hitPosition, ray.Direction);

        HitInfo hitInfo;
        hitInfo.clear();
        TracePrimaryRay(ray, hitInfo);
        hitT = hitInfo.hitT;

        hitPosition = ray.Origin + hitT * ray.Direction;

    #if 1
        // Load surface properties
        ObjectInstance objectInstance = objectInstances[hitInfo.instIdx];
        GeometryInfo geometryInfo = getGeometryInfo(hitInfo, ray.Direction);
        SurfaceInfo surfaceInfo = getSurfaceInfo(objectInstance, geometryInfo);
        
        bool isSky = (hitT >= MAX_RAY_DISTANCE) || objectInstance.flags & objectFlagSunOrMoon;

        // Retrieve surface properties
        float3 hitPosition = ray.Origin + hitInfo.hitT * ray.Direction;
        float3 albedo = surfaceInfo.albedo.rgb;
        float opacity = surfaceInfo.opacity;
        float3 emission = surfaceInfo.emission.rgb * emissiveIntensity;
        float3 normal = surfaceInfo.normal;
        float roughness = surfaceInfo.roughness;
        float metalness = surfaceInfo.metalness;
        float3 motion = geometryInfo.motion;

        // Convert properties to buffer format
        float4 positionAndHitT = float4(hitPosition, hitT);
        float4 albedoAndRoughness = float4(albedo, roughness);
        float4 emissionAndMetalness = float4(emission, metalness);
        float2 opacityAndCategory = float2(opacity, objectInstance.objectCategory);
        float3 worldPos = hitPosition - g_view.waveWorksOriginInSteveSpace;
        worldPos = worldPos - floor(worldPos / 1024) * 1024;

        // Sample normal map if available
        PBRTextureData pbrTextureData = pbrTextureDataBuffer[geometryInfo.pbrTextureDataIdx];
        Texture2D atlas = textures[objectInstance.colourTextureIdx];
        if (pbrTextureData.flags & pbrTextureFlagHasNormalTexture)
        {
            float2 pbrUV = mad(geometryInfo.uv, pbrTextureData.colourToNormalUvScale, pbrTextureData.colourToNormalUvBias);
            float3 pbrTangent = atlas.SampleLevel(defaultSampler, pbrUV, 0).xyz * 2.0 - 1.0;
            normal = (geometryInfo.tangent   * pbrTangent.x) +
                    (geometryInfo.bitangent * pbrTangent.y) +
                    (geometryInfo.normal    * max(pbrTangent.z, 0.01));
        }

        if (isSky)
        {
            normal = -ray.Direction;
            albedo = float3(0.0, 0.0, 0.0);
        }

        if (bounce == 0)
        {
            PopulateGBuffer(ipos, isSky, ray.Direction, positionAndHitT, albedoAndRoughness, 
                            emissionAndMetalness, opacityAndCategory, normal, hitInfo.instIdx, motion);
        }
    #endif
        
        #if 0 // Debug view
        #if 1 // Multiple debug
            if (uv.x > 0.0) outputBufferRawFinal[ipos] = float4(normal + 1.0 / 2.0, 1.0);
            if (uv.x > 0.2) outputBufferRawFinal[ipos] = float4(emission.rgb, 1.0);
            if (uv.x > 0.4) outputBufferRawFinal[ipos] = float4(albedo.rgb, 1.0);
            if (uv.x > 0.6) outputBufferRawFinal[ipos] = float4(hitPosition, 1.0);
            if (uv.x > 0.8) outputBufferRawFinal[ipos] = float4(opacity, objectInstance.objectCategory, 0.0, 1.0);
            return;
        #else // Splitscreen
            if (uv.x > 0.0) 
            {
                uint2 samplePos = uint2(ipos.x - g_view.renderResolution.x / 2.0, ipos.y);
                // outputBufferRawFinal[ipos] = float4((outputBufferMotionVectors[ipos]), 0.0, 1.0);
                return;
            }
        #endif
        #endif

        albedo = pow(albedo, 2.2);
        #if WHITE_FURNACE_TEST
            albedo = float3(1.0, 1.0, 1.0); // White furnace test
        #endif

        if (isSky) // Sky hit
        {
            totalRadiance += throughput * sampleSky(ray.Direction, bounce == 0);
        }
        else // Object hit
        {
            totalRadiance += throughput * emission;

            if (metalness < 0.5) // Dielectric surface
            {
                // --- Explicit sun sampling ---
                float3 directSun = float3(0, 0, 0);
                float NdotL = saturate(dot(normal, g_view.directionToSun));
                if (NdotL > 0.0)
                {
                    float3 Li = sampleSun(normal, hitPosition, randFloat2(randSeed).xy);

                    // Lambertian BRDF
                    float3 brdf_sun = albedo * INV_PI;
                    directSun = brdf_sun * Li * NdotL;
                }


                // --- Sample next bounce direction ---
                float3 wi = float3(0, 0, 0);
                float cosTheta = 0.0;
                
                cosineHemisphereSample(normal, randFloat2(randSeed), wi, cosTheta);

                // PDF for cosine-weighted hemisphere sampling
                float pdf = cosTheta * INV_PI; 

                // Lambertian BRDF
                float3 brdf = albedo * INV_PI; 

                totalRadiance += throughput * directSun;
                throughput *= (brdf * cosTheta) / pdf;

                ray.Direction = wi;
            }
            else // Metallic surface
            {
                float3 wi = normalize(reflect(ray.Direction, normal) + sphereSample(randSeed) * roughness * roughness);
                
                float pdf = 1.0;

                ray.Direction = wi;
                throughput *= albedo * opacity * pdf;
            }

        }

        if (all(ray.Direction == 0.0)) 
        {
            break;
        }
    }
    



// #if 0 // Debug view
// #if 0 // Multiple debug
//     if (uv.x > 0.0) outputBufferRawFinal[ipos] = float4((octToNdirSnorm(outputBufferNormal[ipos]) + 1) / 2, 1.0);
//     if (uv.x > 0.2) outputBufferRawFinal[ipos] = outputBufferEmissionAndMetalness[ipos];
//     if (uv.x > 0.4) outputBufferRawFinal[ipos] = outputBufferAlbedoAndRoughness[ipos];
//     if (uv.x > 0.6) outputBufferRawFinal[ipos] = outputBufferPositionAndHitT[ipos];
//     if (uv.x > 0.8) outputBufferRawFinal[ipos] = float4(outputBufferOpacityAndObjectCategory[ipos], 0.0, 1.0);
//     return;
// #else // Splitscreen
//     if (uv.x > 0.0) 
//     {
//         uint2 samplePos = uint2(ipos.x - g_view.renderResolution.x / 2.0, ipos.y);
//         // outputBufferRawFinal[ipos] = float4((outputBufferMotionVectors[ipos]), 0.0, 1.0);
//         return;
//     }
// #endif
// #endif

//     // Surface properties
//     float3 albedo = pow(outputBufferAlbedoAndRoughness[ipos].rgb, 2.2);
// #if WHITE_FURNACE_TEST
//     albedo = float3(1.0, 1.0, 1.0); // White furnace test
// #endif
//     float opacity = outputBufferOpacityAndObjectCategory[ipos].x;
//     float objectCategory = outputBufferOpacityAndObjectCategory[ipos].y;
//     float3 emission = outputBufferEmissionAndMetalness[ipos].rgb;
//     float3 normal = octToNdirSnorm(outputBufferNormal[ipos]);
//     float roughness = outputBufferAlbedoAndRoughness[ipos].a;
//     float metalness = outputBufferEmissionAndMetalness[ipos].a;
//     float3 hitPosition = outputBufferPositionAndHitT[ipos].xyz;
//     float primaryT = outputBufferPositionAndHitT[ipos].w;
//     float2 prevMotionVectors = outputBufferMotionVectors[ipos].xy;

//     float3 totalRadiance = 0.0;
//     float3 throughput = 1.0;
//     float3 steveWorldPos = g_view.waveWorksOriginInSteveSpace;
//     float hitT = MAX_RAY_DISTANCE;

//     RayDesc ray;
//     ray.TMax = MAX_RAY_DISTANCE;
//     ray.Direction = getPrimaryRayDir(ndcCoords);
//     HitInfo currentHitInfo;
//     currentHitInfo.clear();

//     bool terminate = false;
//     if (primaryT >= MAX_RAY_DISTANCE) // Sky hit
//     {
//         terminate = true;
//         if (any(hitPosition > 0.1) && any(albedo))
//         {
//             // totalRadiance += throughput * sampleSunTexture(ray.Direction, albedo);
//             totalRadiance += throughput * sampleSky(ray.Direction, true);
//             // totalRadiance += float3(1.0, 0.0, 0.0);
//         }
//         else
//         {
//             totalRadiance += throughput * sampleSky(ray.Direction, true);
//             // totalRadiance += float3(0.0, 0.0, 1.0);
//         }
//     }
//     if (!terminate) {
//         totalRadiance += throughput * emission;
        
//         if (metalness < 0.5) // Dielectric surface
//         {
//             float reflectance = R_0 + (1.0 - R_0) * pow(1.0 - saturate(dot(normal, -ray.Direction)), 5.0);
//             reflectance = 0.0;
//             if (randFloat(randSeed) > reflectance) // Diffuse
//             {
//                 // --- Explicit sun sampling ---
//                 float3 directSun = float3(0, 0, 0);
//                 float NdotL = saturate(dot(normal, g_view.directionToSun));
//                 if (NdotL > 0.0)
//                 {
//                     float3 Li = sampleSun(normal, hitPosition, loadBlueNoise4(ipos).xy);

//                     // Lambertian BRDF
//                     float3 brdf_sun = albedo * INV_PI;
//                     directSun = brdf_sun * Li * NdotL;
//                 }


//                 // --- Sample next bounce direction ---
//                 float3 wi = float3(0, 0, 0);
//                 float cosTheta = 0.0;
                
//                 cosineHemisphereSample(normal, loadBlueNoise4(ipos).xy, wi, cosTheta);

//                 // PDF for cosine-weighted hemisphere sampling
//                 float pdf = cosTheta * INV_PI; 

//                 // Lambertian BRDF
//                 float3 brdf = albedo * INV_PI; 

//                 totalRadiance += throughput * directSun;
//                 throughput *= (brdf * cosTheta) / pdf;

//                 ray.Direction = wi;
//             }
//             else // Specular
//             {
//                 // float3 wi = reflect(ray.Direction, normal);
//                 // ray.Direction = wi;

//                 // throughput *= opacity;
//             }
//         }
//         else // Metallic surface
//         {
//             float3 wi = normalize(reflect(ray.Direction, normal) + sphereSample(randSeed) * roughness * roughness);
//             // float3 roughnessDeviation = sampleGGX(randSeed, normal, roughness);
//             // float3 wi = sampleGGX(randSeed, normal, 0.05);
            
//             float pdf = 1.0;

//             ray.Direction = wi;
//             throughput *= albedo * opacity * pdf;
//         }
//     }

//     for (int bounce = 0; bounce < 2; bounce++)
//     {
//         if (terminate) break;
//         if (all(ray.Direction == 0.0)) 
//         {
//             break;
//         }
//         ray.TMin = 0.0001f;
//         ray.Origin = offsetRay(hitPosition, normal);
//         TracePrimaryRay(ray, currentHitInfo);
        
//         // Load surface properties
//         hitT = currentHitInfo.hitT;
//         hitPosition = ray.Origin + hitT * ray.Direction;

//         ObjectInstance object = objectInstances[currentHitInfo.instIdx];
//         GeometryInfo geometryInfo = getGeometryInfo(currentHitInfo, ray.Direction);
//         SurfaceInfo surfaceInfo = getSurfaceInfo(object, geometryInfo);
        
//         albedo = pow(surfaceInfo.albedo.rgb, 2.2);
// #if WHITE_FURNACE_TEST
//         albedo = float3(1.0, 1.0, 1.0);
// #endif
//         opacity = surfaceInfo.opacity;
//         emission = surfaceInfo.emission.rgb * emissiveIntensity;
//         normal = normalize(surfaceInfo.normal);
//         roughness = surfaceInfo.roughness;
//         metalness = surfaceInfo.metalness;

//         if (!currentHitInfo.hasHit())
//         { 
//             // Sky hit
//             totalRadiance += throughput * sampleSky(ray.Direction);
//             break;
//         }
//         if (object.flags & objectFlagSunOrMoon)
//         { 
//             // Sun/Moon hit
//             totalRadiance += throughput * sampleSky(ray.Direction); // sample sky instead, reduces fireflies
//             break;
//         }
//         else
//         {
//             totalRadiance += throughput * emission;

//             if (metalness < 0.5 || true) // Dielectric surface
//             {
//                 // --- Explicit sun sampling ---
//                 float3 directSun = float3(0, 0, 0);
//                 float NdotL = saturate(dot(normal, g_view.directionToSun));
//                 if (NdotL > 0.0)
//                 {
//                     float3 Li = sampleSun(normal, hitPosition, float2(0.0, 0.0));

//                     // Lambertian BRDF
//                     float3 brdf = albedo * INV_PI;
//                     directSun = brdf * Li * NdotL;
//                 }


//                 // --- Sample next bounce direction ---
//                 float3 wi = float3(0, 0, 0);
//                 float cosTheta = 0.0;
//                 cosineHemisphereSample(normal, randFloat2(randSeed), wi, cosTheta);

//                 // PDF for cosine-weighted hemisphere sampling
//                 float pdf = cosTheta * INV_PI; 

//                 // Lambertian BRDF
//                 float3 brdf = albedo * INV_PI; 

//                 totalRadiance += throughput * directSun;
//                 throughput *= (brdf * cosTheta) / pdf;

//                 ray.Direction = wi;
//             }

//             else // Metallic surface
//             {
//                 // TODO
//                 float3 wo = normalize(reflect(ray.Direction, normal) + sphereSample(randSeed) * roughness * roughness);
//                 float pdf = 1.0; // Simplified for metallic surfaces

//                 ray.Direction = wo;
//                 throughput *= albedo * opacity * pdf;
//             }
//         }

//     }



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
}