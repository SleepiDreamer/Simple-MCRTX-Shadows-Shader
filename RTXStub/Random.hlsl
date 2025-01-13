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