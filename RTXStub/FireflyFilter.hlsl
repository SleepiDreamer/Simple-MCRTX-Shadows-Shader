[numthreads(16, 16, 1)]
void DiffuseFireflyFilter(uint2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void DiffuseFireflyFilterSH(uint2 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void SpecularFireflyFilter(
	int2  launchIdx      : SV_DispatchThreadID,
	int2  groupIdx : SV_GroupID,
	int2  groupThreadIdx : SV_GroupThreadID) {}