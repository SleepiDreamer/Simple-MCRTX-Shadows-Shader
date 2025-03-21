#include "Atmosphere.hlsl"
#include "Camera.hlsl"
#include "Common.hlsl"
#include "Helpers.hlsl"

// Multiply the combined lighting effects by current exposure.
[numthreads(16, 16, 1)]
void FinalCombine(uint2 iposCurrentPixels: SV_DispatchThreadID)
{
    float3 finalColour = inputBufferRawFinal[iposCurrentPixels].rgb;
    float exposure = inputBufferIncidentLight[0].r;
    outputBufferFinal[iposCurrentPixels] = float4(finalColour * exposure, 0.0);
}

float3 BicubicSampleCatmullRom(Texture2D tex, SamplerState samp, float2 samplePos, float2 recipTextureResolution)
{
    float2 tc = floor(samplePos - 0.5) + 0.5;
    float2 f = saturate(samplePos - tc);
    float2 f2 = f * f;
    float2 f3 = f2 * f;

    float2 w0 = f2 - 0.5 * (f3 + f);
    float2 w1 = 1.5 * f3 - 2.5 * f2 + 1;
    float2 w3 = 0.5 * (f3 - f2);
    float2 w2 = 1 - w0 - w1 - w3;

    float2 w12 = w1 + w2;

    float2 tc0 = (tc - 1) * recipTextureResolution;
    float2 tc12 = (tc + w2 / w12) * recipTextureResolution;
    float2 tc3 = (tc + 2) * recipTextureResolution;

    float3 result =
        tex.SampleLevel(samp, float2(tc0.x, tc0.y), 0).rgb * (w0.x * w0.y) +
        tex.SampleLevel(samp, float2(tc0.x, tc12.y), 0).rgb * (w0.x * w12.y) +
        tex.SampleLevel(samp, float2(tc0.x, tc3.y), 0).rgb * (w0.x * w3.y) +
        tex.SampleLevel(samp, float2(tc12.x, tc0.y), 0).rgb * (w12.x * w0.y) +
        tex.SampleLevel(samp, float2(tc12.x, tc12.y), 0).rgb * (w12.x * w12.y) +
        tex.SampleLevel(samp, float2(tc12.x, tc3.y), 0).rgb * (w12.x * w3.y) +
        tex.SampleLevel(samp, float2(tc3.x, tc0.y), 0).rgb * (w3.x * w0.y) +
        tex.SampleLevel(samp, float2(tc3.x, tc12.y), 0).rgb * (w3.x * w12.y) +
        tex.SampleLevel(samp, float2(tc3.x, tc3.y), 0).rgb * (w3.x * w3.y);

    return max(0, result);
}

float sampleWeight(float2 delta, float scale)
{
    float x = scale * dot(delta, delta);
    return clamp(1.0 - x, 0.05, 1.0);
}

// Reads from the final output and one of the TAA double buffers and write to the other TAA double buffer.
// Only used when DLSS/Upscaling is turned off.
[numthreads(16, 16, 1)]
void TAA(int2 DTid: SV_DispatchThreadID)
{
#if 1 // Disable TAA
    int x = DTid.x;
    int y = DTid.y;

    float2 nearestRenderPos = float2(x + 0.5f, y + 0.5f) * g_view.renderResolutionDivDisplayResolution - g_view.subPixelJitter - 0.5f;
    int2 intRenderPos = int2(round(nearestRenderPos.x), round(nearestRenderPos.y));
    outputBufferTAAHistory[DTid] = inputBufferFinalColour[intRenderPos];
    return;
#else
    int x = DTid.x;
    int y = DTid.y;

    // Calculate position in the render buffer (at the lower render resolution)
    float2 nearestRenderPos = float2(x + 0.5f, y + 0.5f) * g_view.renderResolutionDivDisplayResolution - g_view.subPixelJitter - 0.5f;
    int2 intRenderPos = int2(round(nearestRenderPos.x), round(nearestRenderPos.y));

    float4 currentColor = inputBufferFinalColour[intRenderPos];
    float2 motionPixels = inputBufferMotionVectors[intRenderPos];

    float3 c1 = currentColor.rgb;
    float3 c2 = currentColor.rgb * currentColor.rgb;
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            if (i == 0 && j == 0)
                continue;

            int2 p = intRenderPos + int2(i, j);

            float3 c = inputBufferFinalColour[p].rgb;
            float2 mv = inputBufferMotionVectors[p];
            c1 = c1 + c;
            c2 = c2 + c * c;
            if (dot(mv, mv) > dot(motionPixels, motionPixels))
            {
                motionPixels = mv;
            }
        }
    }

    motionPixels *= g_view.renderResolution;

    c1 = c1 / 9.0f;
    c2 = c2 / 9.0f;
    float3 extent = sqrt(max(0.0f, c2 - c1 * c1));
    float motionWeight = smoothstep(0, 1.0f, sqrt(dot(motionPixels, motionPixels)));
    float bias = lerp(4.0f, 1.0f, motionWeight);
    float3 minValidColour = c1 - extent * bias;
    float3 maxValidColour = c1 + extent * bias;

    float2 posPreviousPixels = float2(x + 0.5f, y + 0.5f) + motionPixels * g_view.displayResolutionDivRenderResolution;
    posPreviousPixels = clamp(posPreviousPixels, float2(0, 0), g_view.displayResolution - 1.0f);
    float3 prevColor = BicubicSampleCatmullRom(inputTAAHistory, linearSampler, posPreviousPixels, g_view.recipDisplayResolution);
    prevColor = min(maxValidColour, max(minValidColour, prevColor));

    if (currentColor.a != 0)
    {
        nearestRenderPos += g_view.subPixelJitter - g_view.previousSubPixelJitter;
    }

    float pixelWeight = max(motionWeight, sampleWeight(nearestRenderPos - intRenderPos, g_view.displayResolutionDivRenderResolution)) * 0.1f;

    float3 finalColor = lerp(prevColor, currentColor.rgb, pixelWeight);
    outputBufferTAAHistory[int2(x, y)] = float4(finalColor, 0);
#endif
}

// Write TAA output to final output buffer.
// Only used when DLSS/Upscaling is turned off.
[numthreads(16, 16, 1)]
void CopyToFinal(uint2 iposCurrentPixels: SV_DispatchThreadID)
{
    float3 finalColour = inputThisFrameTAAHistory[iposCurrentPixels].rgb;
    outputBufferFinal[iposCurrentPixels] = float4(finalColour, 0);
}

[numthreads(16, 16, 1)]
void CheckerboardInterleave(uint2 iposCurrentPixels: SV_DispatchThreadID)
{
}
