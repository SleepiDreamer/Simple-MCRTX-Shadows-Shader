cbuffer FragmentUniforms : register(b1) {
    float4 gToneMappingDebugMode;
    float4 gToneMappingSaturation;
    float4 gToneMappingShadowContrastEnd;
    float4 gToneMappingShadowContrast;
    float4 ScreenSize;
    float4 gBloomMultiplier;
    float4 gColorGradingEnabled;
    float4 gPerformSRGBConversion;
    float4 gToneMappingColorBalance;
    float4 gToneMappingContrast;
    float4 gToneMappingFilmicSaturationCorrection;
    float4 gToneMappingGamma;
    float4 gToneMappingIntensity;
};

struct PSInput {
    float4 position : SV_Position;
    float2 texcoord0 : TEXCOORD0;
};

// Bind registers automatically.
#define _CONCAT(A, B) A ## B
#define CONCAT(A, B) _CONCAT(A, B)

SamplerState s_RasterColorSampler           : register(CONCAT(s, s_RasterColor_REG));
SamplerState s_gToneCurveSampler            : register(CONCAT(s, s_gToneCurve_REG));
SamplerState s_gRasterizedInputSampler      : register(CONCAT(s, s_gRasterizedInput_REG));
SamplerState s_gBloomBufferSampler          : register(CONCAT(s, s_gBloomBuffer_REG));
Texture2D<float4> s_RasterColorTexture      : register(CONCAT(t, s_RasterColor_REG));
Texture2D<float4> s_gToneCurveTexture       : register(CONCAT(t, s_gToneCurve_REG));
Texture2D<float4> s_gRasterizedInputTexture : register(CONCAT(t, s_gRasterizedInput_REG));
Texture2D<float4> s_gBloomBufferTexture     : register(CONCAT(t, s_gBloomBuffer_REG));

float4 main(PSInput input) : SV_Target0 {
    float4 rasterColor = s_RasterColorTexture.Sample(s_RasterColorSampler, input.texcoord0);
    float4 bloomColor = s_gBloomBufferTexture.Sample(s_gBloomBufferSampler, input.texcoord0);

    float3 color = mad(bloomColor.rgb, gBloomMultiplier.rgb, rasterColor.rgb);
    
	// Currently lacking a full reverse-engineering of this part :(
	uint var6 = (uint(abs(ScreenSize.x * input.texcoord0.x)) << 16u) + uint(abs(ScreenSize.y * input.texcoord0.y));
    uint var7 = ((var6 ^ 61u) ^ (var6 >> 16u)) * 9u;
    uint var8 = ((var7 >> 4u) ^ var7) * 668265261u;
    float var9 = (1.0 / 510.0) - (float((var8 >> 15u) ^ var8) * 1.826122803319507603703186759958e-12f);
    float4 rasterizedInput = s_gRasterizedInputTexture.Sample(s_gRasterizedInputSampler, input.texcoord0);
    float alpha = 1.0f - rasterizedInput.w;

    return float4(rasterizedInput.rgb + ((var9 + color) * alpha), 1.0);
}
