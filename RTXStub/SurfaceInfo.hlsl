#ifndef _SURFACEINFO_HLSL_
#define _SURFACEINFO_HLSL_

#include "Common.hlsl"
#include "Helpers.hlsl"

// Get the geometry info from hit info and the incoming ray direction.
GeometryInfo getGeometryInfo(in HitInfo hitInfo, in float3 rayDirection = 0..xxx)
{
    uint instanceIdx = hitInfo.instIdx;
    ObjectInstance objectInstance = objectInstances[instanceIdx];

    uint3 indices = getTriangleIndices(objectInstance, hitInfo.triIdx);

    GeometryInfo geometryInfo = (GeometryInfo)0;

    FaceData faceData = getFaceData(objectInstance, hitInfo.triIdx);
    geometryInfo.normal = unpackNormal(faceData.packedNormal);
    geometryInfo.tangent = unpackNormal(faceData.packedTangent);
    geometryInfo.bitangent = unpackNormal(faceData.packedBitangent);
    geometryInfo.pbrTextureDataIdx = 0;

    float3 previousPosition = 0;

    float3 barycentrics = float3((1.0f - hitInfo.barycentrics.x - hitInfo.barycentrics.y), hitInfo.barycentrics.x, hitInfo.barycentrics.y);

    float3 positions[3];
    float2 uvs[3];

    ByteAddressBuffer vertexBuffer = vertexBuffers[int(objectInstance.vbIdx)];
    [unroll]
    for (uint i = 0; i < 3; i++)
    {
        int address = (indices[i] + objectInstance.vertexOffsetInBaseVertices) * objectInstance.vertexStride;

        uint4 packedPosNormColor = vertexBuffer.Load4(address);
        float16_t4 vertPos = vertexBuffer.Load<float16_t4>(address + objectInstance.positionByteOffset());
        float4 vertColour = unpackVertexColour(vertexBuffer.Load<uint>(address + objectInstance.colourByteOffset()));
        float2 vertUv = unpackVertexTexCoord(vertexBuffer.Load(address + objectInstance.uv0ByteOffset()));

        if (objectInstance.flags & objectFlagHasMotionVectors)
        {
            float16_t4 vertPrevPos = vertexBuffer.Load<float16_t4>(address + objectInstance.previousPositionByteOffset());
            previousPosition += vertPrevPos.xyz * barycentrics[i];
        }
        if (i == 0)
        {
            if (objectInstance.flags & objectFlagChunk)
                geometryInfo.pbrTextureDataIdx = vertexBuffer.Load(address + objectInstance.pBRTextureIdxByteOffset()) & 0xffff;
        }

        geometryInfo.position += vertPos.xyz * barycentrics[i];
        geometryInfo.uv += vertUv * barycentrics[i];
        geometryInfo.colour += vertColour * barycentrics[i];

        positions[i] = vertPos.xyz;
        uvs[i] = vertUv;
    }

    geometryInfo.isFrontFace = true;

    // Transform position into world space
    float3 posLS = geometryInfo.position;
    geometryInfo.position = mul(float4(posLS, 1), objectInstance.modelToWorld).xyz;

    geometryInfo.normal = normalize(mul(geometryInfo.normal, (float3x3)objectInstance.modelToWorld));
    geometryInfo.tangent = normalize(mul(geometryInfo.tangent, (float3x3)objectInstance.modelToWorld));
    geometryInfo.bitangent = normalize(mul(geometryInfo.bitangent, (float3x3)objectInstance.modelToWorld));

    // Flip normal if back face was hit.
    if (dot(rayDirection, geometryInfo.normal) > 0)
    {
        geometryInfo.normal = -geometryInfo.normal;
        geometryInfo.isFrontFace = false;
    }

    // Set normal to sun direction to handle broken cloud normals.
    if (objectInstance.flags & objectFlagClouds)
        geometryInfo.normal = g_view.directionToSun;

    float3 prevPosLS = (objectInstance.flags & objectFlagHasMotionVectors) ? previousPosition : posLS;
    previousPosition = mul(float4(prevPosLS, 1), objectInstance.prevModelToWorld).xyz;
    geometryInfo.motion = geometryInfo.position - previousPosition;

    return geometryInfo;
}

// Get the surface info from the object instance and geometry info.
SurfaceInfo getSurfaceInfo(in ObjectInstance objectInstance, in GeometryInfo geometryInfo)
{
    SurfaceInfo surfaceInfo;

    Texture2D atlas = textures[int(objectInstance.colourTextureIdx)];
    bool hasTexture = objectInstance.colourTextureIdx != 0xffff;
    
    float4 colour = float4(1, 1, 1, 1);
    if (hasTexture)
    {
        if (objectInstance.flags & objectFlagSun)
        {
            float2 uv = geometryInfo.uv;
            bool bounded = uv.x <= 1.0 && uv.x >= 0.0 && uv.y <= 1.0 && uv.y >= 0.0;
            colour = bounded ? atlas.SampleLevel(defaultSampler, uv, 0) : 0;
        }
        else colour = atlas.SampleLevel(defaultSampler, geometryInfo.uv, 0);
    }

    if (objectInstance.flags & objectFlagMoon)
    {
        surfaceInfo.albedo = pow(colour.rgb, 1.8f);
        return surfaceInfo;
    } else if (objectInstance.flags & objectFlagSun) {
        surfaceInfo.albedo = pow(colour.rgb, 1.4f);
        return surfaceInfo;
    }

    float3 tintColour = geometryInfo.colour.rgb;
    if (objectInstance.flags & objectFlagHasSeasonsTexture)
    {
        float2 uv = geometryInfo.colour.xy;
        float3 seasonColour = textures[int(objectInstance.secondaryTextureIdx)].SampleLevel(defaultSampler, uv, 0).rgb;
        tintColour = lerp(float3(1.0, 1.0, 1.0), seasonColour * 2.0, geometryInfo.colour.b);
        tintColour *= geometryInfo.colour.a;
        colour.a = 1.0;
    }

    if (objectInstance.flags & objectFlagTextureAlphaControlsVertexColour)
    {
        tintColour = lerp(tintColour, 1.xxx, colour.a);
    }

    // Prevent blocks from applying vertex shading. This solves issues with doors being incorrectly darkened.
    if (!(equal3(tintColour) && objectInstance.flags & objectFlagChunk))
        colour.rgb *= tintColour;

    float4 tintColour0 = expandPackedColour(objectInstance.tintColour0);
    colour.rgb *= lerp(1..xxx, tintColour0.rgb, colour.aaa);

    if (!(objectInstance.flags & objectFlagHasSeasonsTexture))
    {
        if (objectInstance.secondaryTextureIdx != 0xffff)
        {
            float4 texel = textures[int(objectInstance.secondaryTextureIdx)].SampleLevel(defaultSampler, geometryInfo.uv, 0);
            if (objectInstance.flags & objectFlagMaskedMultiTexture)
            {
                float maskedTexture = ceil(dot(texel.rgb, 1..xxx) * (1.0f - texel.a));
                colour.rgb = lerp(texel.rgb, colour.rgb, saturate(maskedTexture));
            }
            else if (objectInstance.flags & objectFlagMultiTexture)
            {
                colour.rgb = lerp(colour.rgb, texel.rgb, texel.a);
                texel = textures[int(objectInstance.tertiaryTextureIdx)].SampleLevel(defaultSampler, geometryInfo.uv, 0);
                texel.rgb *= tintColour0.rgb;
                colour.rgb = lerp(colour.rgb, texel.rgb, texel.a);
            }
            else if (objectInstance.flags & objectFlagMultiplicativeTint)
            {
                texel.rgb *= expandPackedColour(objectInstance.tintColour1).rgb;
                colour.rgb = lerp(colour.rgb, texel.rgb, texel.a);
            }
        }
    }
    if (objectInstance.flags & objectFlagOverlay) {
        float4 overlayColour = expandPackedColour(objectInstance.tintColour1);
        colour.rgb = lerp(colour.rgb, overlayColour.rgb, overlayColour.aaa).rgb;
    }

    PBRTextureData pbrTextureData = pbrTextureDataBuffer[geometryInfo.pbrTextureDataIdx];
    float metalness, roughness, emissive;

    if (pbrTextureData.flags & pbrTextureFlagHasMaterialTexture)
    {
        float2 uv = mad(geometryInfo.uv, pbrTextureData.colourToMaterialUvScale, pbrTextureData.colourToMaterialUvBias);
        float3 texel = atlas.SampleLevel(defaultSampler, uv, 0).rgb;
        metalness = texel.r;
        emissive  = texel.g;
        roughness = texel.b;
    }
    else
    {
        metalness = pbrTextureData.uniformMetalness;
        roughness = pbrTextureData.uniformRoughness;
        emissive  = pbrTextureData.uniformEmissive; 
    }

    surfaceInfo.albedo = colour.rgb;
    surfaceInfo.opacity = colour.a;
    surfaceInfo.metalness = metalness;
    surfaceInfo.emission = colour.rgb * emissive;
    surfaceInfo.roughness = roughness;
    surfaceInfo.normal = geometryInfo.normal;

    return surfaceInfo;
}

#endif