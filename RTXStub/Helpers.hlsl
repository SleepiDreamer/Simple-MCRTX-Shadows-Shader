#ifndef _HELPERS_HLSL_
#define _HELPERS_HLSL_

#include "Common.hlsl"

/** Calculates tangent and bitangent using triangle's UV space for use e.g. by normal mapping */
void computeTangent(float3 pos[4], float2 uv[4], out float3 tangent, out float3 bitangent)
{
    float3 P = pos[1] - pos[0];
    float3 Q = pos[2] - pos[0];

    float s1 = uv[1].x - uv[0].x;
    float t1 = uv[1].y - uv[0].y;
    float s2 = uv[2].x - uv[0].x;
    float t2 = uv[2].y - uv[0].y;

    float m = s1 * t2 - s2 * t1;

    if (m == 0) {
        // There's no difference in UVs to calculate sensible tangents
        // Should not happen for well authored textures, but as a fail safe use
        // these to at least prevent ugly artifacts like black plague in production
        tangent = float3(1, 0, 0);
        bitangent = float3(0, 1, 0);
        return;
    }

    float3 a = P * t2;
    float3 b = Q * s1;

    // We're normalizing B and T, so just take a sign of `m` and skip division
    // float tmp = 1.0f / m;
    float tmp = (m < 0) ? -1 : 1;

    tangent = normalize((t2 * P - t1 * Q) * tmp);
    bitangent = normalize((s1 * Q - s2 * P) * tmp);
}

float2 unpackVertexTexCoord(uint packed)
{
    // Assume UV is 16-bit unorm
    float2 uv;
    uv.x = (float)(packed & 0xffff) * (1.f / 0xffff);
    uv.y = (float)(packed >> 16) * (1.f / 0xffff);
    
    uv = mad(uv, 16384, 0.5);
    uv = floor(uv);
    uv *= 1.f / 16384.f;

    return uv;
}

float2 calculateUv(in uint primitiveIndex, in ObjectInstance objectInstance, in float2 barycentrics2)
{
    float3 barycentrics = float3((1.0f - barycentrics2.x - barycentrics2.y), barycentrics2.x, barycentrics2.y);
    uint bufferIdx = objectInstance.getFaceIndexedBufferIdx();
    uint4 packedFaceUvs = faceUvBuffers[bufferIdx][(primitiveIndex / 2) + objectInstance.calcParallelQuadIdx()];
    if (primitiveIndex & 1) packedFaceUvs.xyz = packedFaceUvs.zwx;
    precise float2 uv = 0..xx;
    [unroll]
    for (uint i = 0; i < 3; i++)
    {
        float2 vertUv = unpackVertexTexCoord(packedFaceUvs[i]);
        uv += vertUv * barycentrics[i];
    }
    return uv;
}

FaceData getFaceData(in ObjectInstance objectInstance, in uint triangleIdx)
{
    StructuredBuffer<FaceData> faceDataBuffer = faceDataBuffers[int(objectInstance.vbIdx)];
    return faceDataBuffer[(triangleIdx / 2) + objectInstance.calcParallelQuadIdx()];
}

uint packNormalComponent(in float component)
{
    float norm = saturate(mad(component, 0.5, 0.5));
    return (uint)(norm * 1023.f);
}

float unpackNormalComponent(uint packed)
{
    return mad((float)(packed & 0x3ff), 2.f / 1023.f, -1.f);
}

uint packNormal(in float3 norm)
{
    uint packed;
    packed = packNormalComponent(norm.x);
    packed |= packNormalComponent(norm.y) << 10;
    packed |= packNormalComponent(norm.z) << 20;
    return packed;
}

float3 unpackNormal(uint packed)
{
    return float3(unpackNormalComponent(packed), unpackNormalComponent(packed >> 10), unpackNormalComponent(packed >> 20));
}

float4 expandPackedColour(uint32_t packed)
{
    return float4(
        (float)((packed >> 24)) * (1.f / 255.f),
        (float)((packed >> 16) & 0xff) * (1.f / 255.f),
        (float)((packed >> 8) & 0xff) * (1.f / 255.f),
        (float)((packed >> 0) & 0xff) * (1.f / 255.f)
		);
}

float4 unpackVertexColour(uint packed)
{
    float4 colour;
    colour.r = (float)((packed >> 0) & 0xff) * (1.f / 0xff);
    colour.g = (float)((packed >> 8) & 0xff) * (1.f / 0xff);
    colour.b = (float)((packed >> 16) & 0xff) * (1.f / 0xff);
    colour.a = (float)((packed >> 24) & 0xff) * (1.f / 0xff);
    return colour;
}

uint3 getTriangleIndices(in ObjectInstance objectInstance, in uint primitiveIdx)
{
    uint3 indices;
    uint quadIdx = primitiveIdx / 2;
    uint quadVertexIdx = (quadIdx * 4);
    if (primitiveIdx & 1)
    {
        // Second triangle in the quad
        indices.x = quadVertexIdx + 2;
        indices.y = quadVertexIdx + 3;
        indices.z = quadVertexIdx + 0;
    }
    else
    {
        // First triangle in the quad
        indices.x = quadVertexIdx + 0;
        indices.y = quadVertexIdx + 1;
        indices.z = quadVertexIdx + 2;
    }

    return indices;
}

float sRGBtoLinearComponent(in float sRGB)
{
    if (sRGB < 0.04045f)
    {
        return sRGB * (1.f / 12.92f);
    }
    else
    {
        return pow((sRGB + 0.055f) * (1.f / 1.055f), 2.4);
    }
}

float3 sRGBtoLinear(in float3 sRGB)
{
    float3 linearColour;
    linearColour.r = sRGBtoLinearComponent(sRGB.r);
    linearColour.g = sRGBtoLinearComponent(sRGB.g);
    linearColour.b = sRGBtoLinearComponent(sRGB.b);
    return linearColour;
}

/** Helper function to reflect the folds of the lower hemisphere
    over the diagonals in the octahedral map.
*/
float2 octWrap(float2 v)
{
    return (1.f - abs(v.yx)) * select(v.xy >= 0.f, 1.f, -1.f);
}

/** Converts normalized direction to the octahedral map (non-equal area, signed normalized).
    \param[in] n Normalized direction.
    \return Position in octahedral map in [-1,1] for each component.
*/
float2 ndirToOctSnorm(float3 n)
{
    // Project the sphere onto the octahedron (|x|+|y|+|z| = 1) and then onto the xy-plane.
    float2 p = n.xy * (1.f / (abs(n.x) + abs(n.y) + abs(n.z)));
    p = (n.z < 0.f) ? octWrap(p) : p;
    return p;
}

/** Converts point in the octahedral map to normalized direction (non-equal area, signed normalized).
    \param[in] p Position in octahedral map in [-1,1] for each component.
    \return Normalized direction.
*/
float3 octToNdirSnorm(float2 p)
{
    float3 n = float3(p.xy, 1.0 - abs(p.x) - abs(p.y));
    n.xy = (n.z < 0.0) ? octWrap(n.xy) : n.xy;
    return normalize(n);
}

// Remaps an input value `x` from the range [`zero`, `one`] to [0, 1].
float remap(in float x, in float zero, in float one)
{
    return (x - zero) / (one - zero);
}

// Computes the luminance of a colour.
inline float luminance(in float3 colour)
{
    return dot(colour, float3(0.2126, 0.7152, 0.0722));
}

// Returns the maximum value in a `float3`.
inline float max3(in float3 v)
{
    return max(v.x, max(v.y, v.z));
}

// Returns 0 if `x` is `NaN`.
inline float3 clampNan(in float3 x)
{
    return any(isnan(x)) ? 0 : x;
}

// Tests if all components in a `float3` are equal.
inline bool equal3(in float3 v)
{
    return v.r == v.g && v.g == v.b;
}

// Example screen blending function.
inline float3 screen(in float3 x, in float3 y)
{
    return 1 - (x - 1) * (y - 1);
}

inline bool AreMatricesEqual(float4x4 A, float4x4 B, float epsilon)
{
    return all(abs(A[0] - B[0]) < epsilon) &&
           all(abs(A[1] - B[1]) < epsilon) &&
           all(abs(A[2] - B[2]) < epsilon) &&
           all(abs(A[3] - B[3]) < epsilon);
}

// Transform a vector from tangent space to world space
float3 TangentToWorld(float3 v, float3 n)
{
    float3 tangent, bitangent;
    if (abs(n.x) > abs(n.z)) {
        tangent = normalize(float3(-n.y, n.x, 0.0f));
    } else {
        tangent = normalize(float3(0.0f, -n.z, n.y));
    }
    bitangent = cross(n, tangent);
    
    return v.x * tangent + v.y * bitangent + v.z * n;
}

float3 halfwayVector(float3 v1, float3 v2)
{
    return normalize(v1 + v2);
}

#endif