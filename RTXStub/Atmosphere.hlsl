#ifndef _ATMOSPHERE_HLSL_
#define _ATMOSPHERE_HLSL_

#include "Common.hlsl"
#include "Helpers.hlsl"

static const float3 zenithColour = float3(0.5, 0.7, 1.0);
static const float3 nadirColour = float3(0.7, 0.7, 0.7);

// Sample the sky colour according to a ray direction.
float3 sampleSky(in float3 direction) {
#if WHITE_FURNACE_TEST
    return float3(1.0, 1.0, 1.0);
#endif

    // Lerp according to normalized direction y value
    float t = remap(direction.y, -1.0, 1.0);

    // Multiply by half of max incident light from sun, since its max is 2.0
    // This darkens the sky when the sun intensity is low
    float3 color = pow(lerp(nadirColour, zenithColour, t) * max3(g_view.sunColour) * 0.5 * skyIntensity, 2.2);
    color = max(color, float3(0.01, 0.01, 0.05) * skyIntensity); // night time sky
    return color;
}

#endif