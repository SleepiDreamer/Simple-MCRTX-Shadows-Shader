[numthreads(16, 16, 1)]
void TileClassification(
    uint2 iposCurrentPixels: SV_DispatchThreadID,
    uint linearGroupThreadID: SV_GroupIndex) {}
