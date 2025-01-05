// Bind registers automatically.
#define _CONCAT(A, B) A ## B
#define CONCAT(A, B) _CONCAT(A, B)

SamplerState s_gBloomOriginalInputSampler : register(CONCAT(s, s_gBloomOriginalInput_REG));
SamplerState s_RasterColorSampler : register(CONCAT(s, s_RasterColor_REG));
Texture2D<float4> s_gBloomOriginalInputTexture : register(CONCAT(t, s_gBloomOriginalInput_REG));
Texture2D<float4> s_RasterColorTexture : register(CONCAT(t, s_RasterColor_REG));

struct PSInput {
    float4 position : SV_Position;
    float2 texcoord0 : TEXCOORD0;
};

float4 main(PSInput input) : SV_Target0 {
    float3 rasterColor = s_RasterColorTexture.Sample(s_RasterColorSampler, input.texcoord0).rgb;

    return float4(max(rasterColor, 0), 1);
}
