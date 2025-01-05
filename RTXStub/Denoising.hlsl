// Shader entry points
[numthreads(16, 16, 1)]
void FilterMomentsColour(uint2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void FilterMomentsSH(uint2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 8, 1)]
void AtrousColour(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 8, 1)]
void AtrousSH(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void BlendCheckerboardFieldsColour(uint2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void BlendCheckerboardFieldsSH(uint2 iposCurrentPixels : SV_DispatchThreadID) {}
