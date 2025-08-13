#ifndef _ATMOSPHERE_HLSL_
#define _ATMOSPHERE_HLSL_

#include "Common.hlsl"
#include "Helpers.hlsl"

static const float sunAzimuthDeg = 0.0f;
static const float sunZenithDeg = -30.0f;

static const float3 zenithColour = float3(0.5, 0.7, 1.0);
static const float3 nadirColour = float3(0.7, 0.7, 0.7);

float3 getDirectionToSun()
{
    float3 dirToSun = g_view.directionToSun;
    
    // rotate around x axis
    if (sunAzimuthDeg != 0.0)
    {
        float3x3 rotationMatrix = float3x3(
            cos(sunAzimuthDeg * TO_RADIANS),   0,  sin(sunAzimuthDeg * TO_RADIANS),
            0,                      1,  0,
            -sin(sunAzimuthDeg * TO_RADIANS),  0,  cos(sunAzimuthDeg * TO_RADIANS)
        );
        dirToSun = mul(rotationMatrix, dirToSun);
    }
    if (sunZenithDeg != 0.0)
    {
        float3x3 rotationMatrix = float3x3(
            1, 0, 0,
            0, cos(sunZenithDeg * TO_RADIANS), -sin(sunZenithDeg * TO_RADIANS),
            0, sin(sunZenithDeg * TO_RADIANS), cos(sunZenithDeg * TO_RADIANS)
        );
        dirToSun = mul(rotationMatrix, dirToSun);
    }

    return dirToSun;
}

float3 getSunColor()
{
    float3 sunColor = g_view.sunColour;
    float intensity = sunIntensity;
    if (isSunActuallyMoon())
    {
        sunColor = float3(0.8, 0.8, 1.0) * moonIntensity;
        intensity = moonIntensity;
    }
    
    return sunColor * intensity;
}

// Sample the sky colour according to a ray direction.
float3 sampleSky(in float3 direction, bool includeSun = false) {
#if WHITE_FURNACE_TEST
    return float3(1.0, 1.0, 1.0);
#endif
    // Lerp according to normalized direction y value
    float t = remap(direction.y, -1.0, 1.0);

    // Multiply by half of max incident light from sun, since its max is 2.0
    // This darkens the sky when the sun intensity is low
    float3 color = pow(lerp(nadirColour, zenithColour, t) * max3(g_view.sunColour) * 0.5 * skyIntensity, 2.2);
    
    float3 highlight = float3(0.0, 0.0, 0.0);
    if (dot(direction, getDirectionToSun()) > 0.9997 && includeSun) {
        highlight += getSunColor() * 100.0;
    }

    color = max(color, float3(0.16, 0.16, 1.0) * 0.03); // Night time sky

    color += highlight;
    return color;
}

float3 sampleSunTexture(float3 rayDirection, float3 albedo)
{
#if WHITE_FURNACE_TEST
    return float3(1.0, 1.0, 1.0);
#endif
    return (albedo * 15.0) + (1.0 - albedo) * sampleSky(rayDirection);
}

#endif