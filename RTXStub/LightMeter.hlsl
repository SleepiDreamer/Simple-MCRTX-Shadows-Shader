#include "Common.hlsl"
#include "Helpers.hlsl"

// Measures 512 samples of incident light measurement currently in view.
[numthreads(4, 4, 1)]
void MeasureIncidentLight(uint3 launchIndex: SV_DispatchThreadID)
{
    uint2 launchDimensions = uint2((g_rootConstant0 >> 0) & 0xffff, (g_rootConstant0 >> 16) & 0xffff);
    uint linearIndex = launchIndex.x + (launchIndex.y * launchDimensions.x);

    if (launchIndex.z != 0)
    {
        return;
    }

    // Convert the 2D launch index into a screen pixel sampling position
    float2 recipLaunchDimensions = 1..xx / (float2)launchDimensions;
    uint2 samplingCoord = (uint2)((((float2)launchIndex.xy) + 0.5.xx) * recipLaunchDimensions * g_view.fieldSize);

    // Weight is set to 1.0 for now, can be changed as desired.
    float weight = 1.0;

    // Combine indirect and direct diffuse lighting to measure incoming light.
#if 0
    float3 incomingLight = inputBufferDiffuse[samplingCoord].rgb;
    incomingLight += inputBufferSunLight[samplingCoord].rgb;
    incomingLight *= inputBufferPrimaryThroughput[samplingCoord].rgb;

    bool isSky = inputBufferPrimaryPathLength[samplingCoord] == MAX_RAY_DISTANCE;
    if (isSky)
        incomingLight = inputBufferRawFinal[samplingCoord].rgb;
#else
    float3 incomingLight = 1..xxx;
#endif

    int writeIndex = linearIndex + 3;
    outputBufferIncidentLight[writeIndex] = float4(incomingLight, weight);
}

// The desired brigtness of the scene.
// Set to 0.5 for neutral brighness.
static float desiredBrightness = 0.5;

// The minumum bound for the exposure value.
static float minEV = -1.0;

// The maximum bound for the exposure value.
static float maxEV = 0.0;

// The percentage change in exposure value from current to desired each frame.
static float autoExposureSpeed = g_lightMeterSamples.lightAccumulationAlpha;

// Resolve the incident light measurements into a single brightness value to expose to.
[numthreads(1, 1, 1)]
void ResolveExposure(uint idx: SV_DispatchThreadID)
{
    if (idx != 0)
        return;

    // Weighted average of all the incident light samples.
    float totalWeight = 0;
    float3 averageIncomingLight = 0;
    for (int i = 0; i < 512; i++)
    {
        float weight = outputBufferIncidentLight[i + 3].a;
        averageIncomingLight += outputBufferIncidentLight[i + 3].rgb * weight;
        totalWeight += weight;
    }

    // Total brightness, plus a small value to avoid dividing by 0.
    float brightness = max3(averageIncomingLight / totalWeight) + 1.0e-6;

    // The desired exposure value, the ratio between desired and current brightness.
    // If every pixel is multiplied by the desired exposure, then the weighted average
    // of brightness samples will equal the desired brightness.
    float desiredEV = log2(desiredBrightness / brightness);
    // Clamp the desired brightness into the min/max range.
    float targetEV = clamp(desiredEV, minEV, maxEV);

    // Get the previous exposure value.
    float currentEV = outputBufferIncidentLight[1].r;

    // Lerp current exposure value towards the target value, according to the auto 
    // exposure speed.
    float nextEV = lerp(currentEV, targetEV, autoExposureSpeed);

    // Convert exposure value to exposure multiplier.
    float desiredExposure = exp2(desiredEV);
    float nextExposure = exp2(nextEV);

#if 0 // Toggle auto exposure on/off
    // Write to incident light buffer. Index 2 is left unused at the moment.
    outputBufferIncidentLight[0].rg = float2(nextExposure, desiredExposure);
    outputBufferIncidentLight[1].rg = float2(nextEV, desiredEV);
    outputBufferIncidentLight[2].rgb = 1;
#else
    // Write to incident light buffer. Index 2 is left unused at the moment.
    outputBufferIncidentLight[0].rg = float2(1.0f, 1.0f);
    outputBufferIncidentLight[1].rg = float2(1.0f, 1.0f);
    outputBufferIncidentLight[2].rgb = 1;
#endif
}
