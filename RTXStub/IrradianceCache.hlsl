[numthreads(128, 1, 1)]
void ClearVertexIrradianceCache(uint idx: SV_DispatchThreadID) {}

[numthreads(128, 1, 1)]
void ClearFaceIrradianceCache(uint idx: SV_DispatchThreadID) {}

[numthreads(32, 1, 1)]
void UpdateVertexIrradianceCacheInline(uint launchIndex: SV_DispatchThreadID) {}

[numthreads(32, 1, 1)]
void UpdateFaceIrradianceCacheInline(uint launchIndex: SV_DispatchThreadID) {}
