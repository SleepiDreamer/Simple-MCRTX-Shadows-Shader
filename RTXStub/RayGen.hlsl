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

    return payload.transmission * sunColor;
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

    float4 blueNoise4 = loadBlueNoise4(ipos);
    float blueNoise[4] = { blueNoise4.x, blueNoise4.y, blueNoise4.z, blueNoise4.w };

    [unroll]
    for (int bounce = 0; bounce < 4; bounce++)
    {
        if (all(clampNan(ray.Direction) == 0.0)) break;

        // Trace ray
        ray.TMin = 0.0001f;
        ray.Origin = offsetRay(hitPosition, ray.Direction);

        HitInfo hitInfo;
        hitInfo.clear();
        TracePrimaryRay(ray, hitInfo);
        hitT = hitInfo.hitT;

        #if 0 // Alpha blending
        if (bounce < 2 && hitInfo.hasHit())
        {
            float3 rayThroughput;
            TraceThroughputRay(ray, rayThroughput);
            throughput *= rayThroughput;
        }
        #endif        

        hitPosition = ray.Origin + hitT * ray.Direction;

    #if 1
        // Load surface properties
        ObjectInstance objectInstance = objectInstances[hitInfo.instIdx];
        GeometryInfo geometryInfo = getGeometryInfo(hitInfo, ray.Direction);
        SurfaceInfo surfaceInfo = getSurfaceInfo(objectInstance, geometryInfo);
        
        // Retrieve surface properties
        float3 hitPosition = ray.Origin + hitInfo.hitT * ray.Direction;
        float3 albedo = surfaceInfo.albedo.rgb;
        float opacity = surfaceInfo.opacity;
        float3 emission = surfaceInfo.emission.rgb * emissiveIntensity;
        float3 normalGeo = surfaceInfo.normal;
        float roughness = surfaceInfo.roughness;
        float metalness = surfaceInfo.metalness;
        float3 motion = geometryInfo.motion;

        float3 worldPos = hitPosition - g_view.waveWorksOriginInSteveSpace;
        worldPos = worldPos - floor(worldPos / 1024) * 1024;

        // Sample normal map if available
        float3 normal = geometryInfo.normal;
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

        bool isSky = (hitT >= MAX_RAY_DISTANCE) || objectInstance.flags & objectFlagSunOrMoon;
        if (isSky)
        {
            normalGeo = -ray.Direction;
            albedo = float3(0.0, 0.0, 0.0);
        }

        if (bounce == 0)
        {
            // Convert properties to buffer format
            float4 positionAndHitT = float4(hitPosition, hitT);
            float4 albedoAndRoughness = float4(albedo, roughness);
            float4 emissionAndMetalness = float4(emission, metalness);
            float2 opacityAndCategory = float2(opacity, objectInstance.objectCategory);

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

        // check if normal is below normalGeo
        if (dot(normal, normalGeo) < 0.0)
        {
            normal.y = -normal.y;
        }

        if (isSky) // Sky hit
        {
            totalRadiance += throughput * sampleSky(ray.Direction, bounce == 0);
            break;
        }
        else // Object hit
        {
            if (any(emission > 0.0))
            {
                totalRadiance += throughput * emission;
                break; // Stop tracing on emission
            }

            if (metalness < 0.5) // Dielectric surface
            {
                // --- Explicit sun sampling ---
                float3 directSun = float3(0, 0, 0);
                float NdotL = saturate(dot(normal, g_view.directionToSun));
                if (NdotL > 0.0)
                {
                    float2 randomSample = (bounce == 0) ? blueNoise4.xy : randFloat2(randSeed);
                    float3 Li = sampleSun(normal, hitPosition, randomSample);

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
                throughput *= albedo * pdf;
            }
        }

        if (all(ray.Direction == 0.0)) 
        {
            break;
        }
        
        #if 1 // Russian roulette
        if (uv.x >= 0.0)
        {
            float p = min(max3(throughput) * 2.0, 1.0);
            if (randFloat(randSeed) > p)
            {
                break;
            }
            throughput /= p;
        }
        #endif
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
}