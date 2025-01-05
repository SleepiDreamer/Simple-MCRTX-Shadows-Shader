[numthreads(16, 16, 1)]
void AccumulateInscatter(uint2 launchIdx : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void AccumulateGIInscatter(uint2 launchIdx : SV_DispatchThreadID) {}

// Seperable 2D box blur with kernel size depending on history length
[numthreads(16, 16, 1)]
void BlurGIInscatter(int3 launchIdx : SV_DispatchThreadID) {}

[numthreads(4, 4, 2)]
void CalculateInscatterInline(uint3 launchIndex: SV_DispatchThreadID) {}

[numthreads(4, 4, 2)]
void CalculateGIInscatterInline(uint3 launchIndex: SV_DispatchThreadID) {}