[numthreads(16, 16, 1)]
void TemporalDenoising(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void ShadowDenoising(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}


[numthreads(16, 16, 1)]
void FinalizeDenoising(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void BlendCheckerboardFieldsShadow(uint2 iposCurrentPixels : SV_DispatchThreadID) {}
