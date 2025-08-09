#include "Random.hlsl"
#include "Helpers.hlsl"

float3 SampleBRDF(float3 wi, float3 n, float3 albedo, out float3 wo, out float pdf, inout uint randSeed)
{
    // float2 randSample = randFloat2(randSeed);
    // float3 localWo = cosineSampleHemisphere(randSample);
    // wo = TangentToWorld(localWo, n);
    
    // float cosTheta = dot(wo, n);
    
    // pdf = cosTheta / PI;
    
    // float3 brdfValue = albedo / PI;
    
    // return brdfValue;

    return 0;
}

float ggxNormalDistribution(float3 n, float3 h, float roughness)
{
    float cosTheta = dot(n, h);
    float tanTheta = sqrt(max(0.0f, 1.0f - cosTheta * cosTheta)) / cosTheta;
    float alpha2 = roughness * roughness;
    
    return alpha2 / (PI * pow(cosTheta * cosTheta * (alpha2 + tanTheta * tanTheta), 2));
}