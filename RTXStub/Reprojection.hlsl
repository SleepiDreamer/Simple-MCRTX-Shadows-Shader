[numthreads(16, 16, 1)]
void Reproject(
	uint2 iposCurrentPixels : SV_DispatchThreadID,
	uint2 groupId           : SV_GroupID,
	uint2 groupThreadId     : SV_GroupThreadID) {}

[numthreads(16, 16, 1)]
void ReprojectSpecularOnly(
	uint2 iposCurrentPixels : SV_DispatchThreadID,
	uint2 groupId           : SV_GroupID,
	uint2 groupThreadId     : SV_GroupThreadID) {}

[numthreads(16, 16, 1)]
void ReprojectSH(
	uint2 iposCurrentPixels : SV_DispatchThreadID,
	uint2 groupId           : SV_GroupID,
	uint2 groupThreadId     : SV_GroupThreadID) {}
