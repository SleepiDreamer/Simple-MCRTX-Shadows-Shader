#ifndef _RANDOM_HLSL_
#define _RANDOM_HLSL_

#include "Common.hlsl"

uint pcg_hash(uint state) 
{
    uint word = ((state >> ((state >> 28) + 4)) ^ state) * 277803737u;
    word = (word >> 22) ^ word;
    return word;
}

uint randomSample(uint state) 
{
    return pcg_hash(state);
}

uint initSeed(uint2 ipos, uint frame) 
{
    uint seed = ipos.x + ipos.y * g_view.renderResolution.x;
    seed ^= frame * 0x9E3779B9;
    return randomSample(seed);
}

uint nextSeed(inout uint seed)
{
    return randomSample(seed);
}

float nextSeedFloat(inout uint seed)
{
    seed = randomSample(seed);
    return float(seed & 0x00FFFFFF) / float(0x01000000);
}

uint randUint(inout uint seed)
{
    return randomSample(seed);
}

uint2 randUint2(inout uint seed)
{
    return uint2(randUint(seed), randUint(seed));
}

float randFloat(inout uint seed)
{
    return nextSeedFloat(seed);
}

float2 randFloat2(inout uint seed)
{
    return float2(randFloat(seed), randFloat(seed));
}

float3 hemisphereSample(inout uint seed, float3 normal)
{
    float2 r = randFloat2(seed);
    float phi = 2 * PI * r.x;
    float cosTheta = sqrt(1 - r.y);
    float sinTheta = sqrt(r.y);

    float3 tangent = normalize(cross(normal, float3(0, 0, 1)));
    float3 bitangent = normalize(cross(normal, tangent));

    return normalize(
        tangent * sinTheta * cos(phi) +
        bitangent * sinTheta * sin(phi) +
        normal * cosTheta
    );
}

float3 sphereSurfaceSample(inout uint seed)
{
    float2 r = randFloat2(seed);
    float theta = TWO_PI * r.x;
    float phi = acos(1.0f - 2.0f * r.y);

    float x = sin(phi) * cos(theta);
    float y = sin(phi) * sin(theta);
    float z = cos(phi);

    return float3(x, y, z);
}

float3 sphereSample(inout uint seed)
{
    float2 r = randFloat2(seed);
    float theta = TWO_PI * r.x;
    float phi = acos(1.0f - 2.0f * r.y);

    float r2 = pow(randFloat(seed), 1.0f / 3.0f);

    float x = sin(phi) * cos(theta) * r2;
    float y = sin(phi) * sin(theta) * r2;
    float z = cos(phi) * r2;

    return float3(x, y, z);
}

float2 diskSample(inout uint seed)
{
    float2 r = randFloat2(seed);
    float phi = 2 * PI * r.x;
    float rSqrt = sqrt(r.y);
    return float2(rSqrt * cos(phi), rSqrt * sin(phi));
}

float3 diskSample(inout uint seed, float3 normal)
{
    float2 r = diskSample(seed);
    float3 tangent = normalize(cross(normal, float3(0, 0, 1)));
    float3 bitangent = normalize(cross(normal, tangent));
    return tangent * r.x + bitangent * r.y;
}

float3 cosineSampleHemisphere(float2 u) {
    float r = sqrt(u.x);
    float theta = 2.0f * PI * u.y;
    float x = r * cos(theta);
    float y = r * sin(theta);
    float z = sqrt(max(0.0f, 1.0f - u.x)); // upper hemisphere
    return float3(x, y, z);
}

#endif