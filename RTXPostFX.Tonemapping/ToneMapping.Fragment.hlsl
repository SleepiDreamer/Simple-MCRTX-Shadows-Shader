// MIT License
//
// Copyright (c) 2024 Missing Deadlines (Benjamin Wrensch)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// All values used to derive this implementation are sourced from Troy's initial AgX implementation/OCIO config file available here:
//   https://github.com/sobotka/AgX

// 0: Default, 1: Golden, 2: Punchy
#define AGX_LOOK 0

// Mean error^2: 3.6705141e-06
float3 agxDefaultContrastApprox(float3 x) {
  float3 x2 = x * x;
  float3 x4 = x2 * x2;
 
  return + 15.5     * x4 * x2
         - 40.14    * x4 * x
         + 31.96    * x4
         - 6.868    * x2 * x
         + 0.4298   * x2
         + 0.1191   * x
         - 0.00232;
}

float3 agx(float3 val) {
  static const float3x3 agx_mat = float3x3(
    0.842479062253094, 0.0423282422610123, 0.0423756549057051,
    0.0784335999999992,  0.878468636469772,  0.0784336,
    0.0792237451477643, 0.0791661274605434, 0.879142973793104);
   
  static const float min_ev = -12.47393f;
  static const float max_ev = 4.026069f;
  
  // Input transform (inset)
  val = mul(agx_mat, val);
 
  // Log2 space encoding
  val = clamp(log2(val), min_ev, max_ev);
  val = (val - min_ev) / (max_ev - min_ev);
 
  // Apply sigmoid function approximation
  val = agxDefaultContrastApprox(val);
  return val;
}

float3 agxEotf(float3 val) {
  static const float3x3 agx_mat_inv = float3x3(
    1.19687900512017, -0.0528968517574562, -0.0529716355144438,
    -0.0980208811401368, 1.15190312990417, -0.0980434501171241,
    -0.0990297440797205, -0.0989611768448433, 1.15107367264116);
   
  // Inverse input transform (outset)
  val = mul(agx_mat_inv, val);
 
  // sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
  // NOTE: We're linearizing the output here. Comment/adjust when
  // *not* using a sRGB render target
  val = pow(val, float3(2.2, 2.2, 2.2));
  return val;
}

float3 agxLook(float3 val) {  
  // Default
  float3 offset = float3(0.0, 0.0, 0.0);
  float3 slope = float3(1.0, 1.0, 1.0);
  float3 power = float3(1.0, 1.0, 1.0);
  float sat = 1.0;
 
#if AGX_LOOK == 1
  // Golden
  slope = float3(1.0, 0.9, 0.5);
  power = float3(0.8, 0.8, 0.8);
  sat = 0.8;
#elif AGX_LOOK == 2
  // Punchy
  slope = float3(1.0, 1.0, 1.0);
  power = float3(1.35, 1.35, 1.35);
  sat = 1.4;
#endif
 
  // ASC CDL
  val = pow(val * slope + offset, power);
  static const float3 lw = float3(0.2126, 0.7152, 0.0722);
  float luma = dot(val, lw);
  return luma + sat * (val - luma);
}







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

// float4 main(PSInput input) : SV_Target0 {
//     float4 rasterColor = s_RasterColorTexture.Sample(s_RasterColorSampler, input.texcoord0);
//     float4 bloomColor = s_gBloomBufferTexture.Sample(s_gBloomBufferSampler, input.texcoord0);

//     float3 color = mad(bloomColor.rgb, gBloomMultiplier.rgb, rasterColor.rgb);
//     float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
//     float exposureMult = 1.0;
//     float3 tonemapped = (luminance * exposureMult) / ((luminance * exposureMult) + 1.0) * color;

// 	// Currently lacking a full reverse-engineering of this part :(
// 	uint var6 = (uint(abs(ScreenSize.x * input.texcoord0.x)) << 16u) + uint(abs(ScreenSize.y * input.texcoord0.y));
//     uint var7 = ((var6 ^ 61u) ^ (var6 >> 16u)) * 9u;
//     uint var8 = ((var7 >> 4u) ^ var7) * 668265261u;
//     float var9 = (1.0 / 510.0) - (float((var8 >> 15u) ^ var8) * 1.826122803319507603703186759958e-12f);
//     float4 rasterizedInput = s_gRasterizedInputTexture.Sample(s_gRasterizedInputSampler, input.texcoord0);
//     float alpha = 1.0f - rasterizedInput.w;

//     return float4(rasterizedInput.rgb + ((var9 + color) * alpha), 1.0);
// }

float3 gamma_correct(float3 linearCol)
{
    bool3 cutoff = linearCol < 0.0031308;
    float3 higher = 1.055 * pow(linearCol, 1.0 / 2.4) - 0.055;
    float3 lower = linearCol * 12.92;
    return lerp(higher, lower, cutoff);
}

float4 main(PSInput input) : SV_Target0 {
    float4 rasterColor = s_RasterColorTexture.Sample(s_RasterColorSampler, input.texcoord0);
    float4 bloomColor = s_gBloomBufferTexture.Sample(s_gBloomBufferSampler, input.texcoord0);
    float4 rasterizedInput = s_gRasterizedInputTexture.Sample(s_gRasterizedInputSampler, input.texcoord0);

    float exposureMult = 1.0;
    float3 exposedColor = mad(bloomColor.rgb, gBloomMultiplier.rgb, rasterColor.rgb) * exposureMult;
    float3 luminance = dot(exposedColor, float3(0.2126, 0.7152, 0.0722));

    // reinhard tonemapping
    float3 tonemapped = pow(exposedColor / (exposedColor + 1.0), 1.0);
    // blend rasterized and RT
    float3 final = gamma_correct(rasterizedInput.rgb + tonemapped * (1.0 - rasterizedInput.a));
    // float3 final = exposedColor;

    // float exposureMult = 1.0;
    // float3 exposedColor = (bloomColor.rgb, gBloomMultiplier.rgb, rasterColor.rgb) * exposureMult;
    // float3 color = agx(exposedColor);
    // color = agxLook(color);
    // color = agxEotf(color);

    // float3 final = color;

    return float4(final, 1.0);
}