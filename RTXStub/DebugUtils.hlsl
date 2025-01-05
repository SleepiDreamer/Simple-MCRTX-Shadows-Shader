[numthreads(16, 16, 1)]
void DrawString(
	int3 groupID           : SV_GroupID,
	int3 groupThreadID     : SV_GroupThreadID,
	int3 iposCurrentPixels : SV_DispatchThreadID) {}


[numthreads(16, 16, 1)]
void DrawPlot(
    int3 groupID           : SV_GroupID,
    int3 groupThreadID     : SV_GroupThreadID,
    int3 iposCurrentPixels : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void WFTest(
	int2 groupID       : SV_GroupID,
	int2 groupThreadID : SV_GroupThreadID,
	int2 LaunchIndex : SV_DispatchThreadID) {}

[numthreads(16, 16, 1)]
void DrawLights(
	int3 groupID           : SV_GroupID,
	int3 groupThreadID     : SV_GroupThreadID,
	int3 iposCurrentPixels : SV_DispatchThreadID) {}
