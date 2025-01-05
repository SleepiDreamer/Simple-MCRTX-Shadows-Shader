[numthreads(16, 16, 1)]
void ToneMappingHistogram(
    int2 groupID       : SV_GroupID,
    int2 groupThreadID : SV_GroupThreadID,
    uint linearIndex   : SV_GroupIndex, // Equivalent to gl_LocalInvocationIndex
    int2 ipos          : SV_DispatchThreadID)
{
}

[numthreads(256, 1, 1)]
void ToneCurve(
    int2 groupID           : SV_GroupID,
    int2 groupThreadID     : SV_GroupThreadID,
    uint linearIndex       : SV_GroupIndex,
    int2 iposCurrentPixels : SV_DispatchThreadID)
{
}