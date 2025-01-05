[numthreads(16, 16, 1)]
void CheckerboardUpscale(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void CheckerboardUpscaleSH(
	int2 groupID           : SV_GroupID,
	int2 groupThreadID     : SV_GroupThreadID,
	int2 iposCurrentPixels : SV_DispatchThreadID) {}