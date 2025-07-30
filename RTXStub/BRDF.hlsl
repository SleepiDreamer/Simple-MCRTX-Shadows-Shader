#include "Random.hlsl"
#include "Helpers.hlsl"

float3 SampleBRDF(float3 wi, float3 n, float3 albedo, out float3 wo, out float pdf, inout uint randSeed)
{
    float2 randSample = randFloat2(randSeed);
    float3 localWo = cosineSampleHemisphere(randSample);
    wo = TangentToWorld(localWo, n);
    
    float cosTheta = dot(wo, n);
    
    pdf = cosTheta / PI;
    
    float3 brdfValue = albedo / PI;
    
    return brdfValue;
}