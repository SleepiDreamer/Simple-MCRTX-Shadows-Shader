cbuffer FragmentUniforms : register(b1) {
    float4 ScreenSize;
};

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

#define KERNEL_STEP_SIZE (2)

static const float bloomGauss[4] = { 0.1633996963500976562f,
                                     0.0387139283120632171f,
                                     0.0387139283120632171f,
                                     0.0091724051162600517f };

float4 main(PSInput input) : SV_Target0 {
    float2 screenSize = ScreenSize.zw;
    float2 halfScreenSize = screenSize * 0.5;

    float3 color = 0;

    for(int i = -KERNEL_STEP_SIZE; i < KERNEL_STEP_SIZE; ++i){
        for(int j = -KERNEL_STEP_SIZE; j < KERNEL_STEP_SIZE; ++j){
            float2 pixelPos = float2(i, j) * screenSize;
            uint index = ((j >> 31) ^ j) + (((i >> 31) ^ i) * 2u);
            float weight = bloomGauss[index];
            float2 uv = halfScreenSize + input.texcoord0 + pixelPos;
            float3 rasterColor = s_RasterColorTexture.Sample(s_RasterColorSampler, uv).rgb;
            color += rasterColor * weight;
        }
    }

    return float4(color, 1);
}
